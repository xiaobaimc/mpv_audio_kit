// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.
//
// End-to-end media-session test on the REAL OS. Runs the full path —
// Dart `Player` → `MediaSessionController` → method channel →
// `MediaSessionPlugin` → `MPNowPlayingInfoCenter` — on a real iOS
// simulator / macOS, then reads the OS-visible Now Playing state back
// through the plugin's `debugNowPlayingInfo` probe. A green run means
// the running app publishes exactly this state to the OS — there is no
// "different world" between the tests and the app.
//
// Apple only: the probe + MPNowPlayingInfoCenter live in the darwin
// plugin. Skipped on other platforms (their bridges have their own
// suites). Cover art is intentionally NOT asserted — iOS currently
// loads an unpatched libmpv that doesn't expose embedded cover art
// (see smoke_test.dart); title / artist / album / duration / state all
// come from standard mpv properties and work everywhere.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '_helpers/asset_fixture.dart';

const _probe = MethodChannel('mpv_audio_kit/media_session');

/// Reads the OS-visible Now Playing snapshot back from the plugin (the
/// real `MPNowPlayingInfoCenter.default()`).
Future<Map<String, Object?>> readNowPlaying() async {
  final raw = await _probe.invokeMethod<Map<Object?, Object?>>(
    'debugNowPlayingInfo',
  );
  return Map<String, Object?>.from(raw ?? const {});
}

/// Polls [readNowPlaying] until [predicate] holds or the timeout fires.
/// Returns the last snapshot so the caller can assert on it (and get a
/// useful failure message). Method-channel pushes are async, so a
/// settled assertion needs a poll, not a fixed delay.
Future<Map<String, Object?>> pumpUntil(
  bool Function(Map<String, Object?>) predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  var snapshot = await readNowPlaying();
  while (!predicate(snapshot)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Now Playing never satisfied the predicate. Last: $snapshot');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    snapshot = await readNowPlaying();
  }
  return snapshot;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    MpvAudioKit.ensureInitialized(hotRestartCleanup: false);
  });

  // The probe (`debugNowPlayingInfo`) and MPNowPlayingInfoCenter only
  // exist in the Apple plugin.
  final isApple = Platform.isIOS || Platform.isMacOS;

  group('media session — real OS Now Playing', () {
    late Player player;
    late String fixture;

    setUp(() async {
      // ~3s, seekable — long enough for a real seek that doesn't race EOF.
      fixture = await materializeFixture('with_chapters.mka');
      player = Player(
        configuration: const PlayerConfiguration(
          logLevel: LogLevel.off,
        ),
      );
      // Null audio output — simulators expose no real device.
      await player.setRawProperty('ao', 'null');
    });

    tearDown(() async {
      await player.setMediaSession(null);
      await player.stop();
      await player.dispose();
    });

    testWidgets('enable publishes overridden metadata to the OS', (_) async {
      await player.open(Media(fixture), play: false);
      await player.stream.duration
          .firstWhere((d) => d.inMilliseconds > 2500)
          .timeout(const Duration(seconds: 10));

      await player.setMediaSession(const MediaSession(
        title: 'E2E Title',
        artist: 'E2E Artist',
        album: 'E2E Album',
      ),);

      final np = await pumpUntil((s) => s['title'] == 'E2E Title');
      expect(np['artist'], 'E2E Artist');
      expect(np['album'], 'E2E Album');
      expect((np['duration'] as num?)?.toDouble(), greaterThan(2.5),
          reason: 'duration must reach the OS, got ${np['duration']}',);
      // autoPlay:false + opened paused → core-idle true → paused.
      expect(np['playbackState'], 'paused');
    }, skip: !isApple,);

    testWidgets('example flow: setMediaSession BEFORE play, derive from file',
        (_) async {
      // Mirrors the example app EXACTLY: enable the session at startup
      // (no media yet), THEN open + autoplay a real tagged m4a
      // (title/artist/album tags + embedded cover + 2s).
      final tagged = await materializeFixture('tagged.m4a');
      await player.setMediaSession(const MediaSession()); // enable FIRST
      await player.open(Media(tagged), play: true); // then autoplay
      await player.stream.playing
          .firstWhere((p) => p)
          .timeout(const Duration(seconds: 10));
      // Let the incremental metadata pushes (title / duration / cover)
      // settle through the channel.
      await Future<void>.delayed(const Duration(seconds: 1));

      final np = await readNowPlaying();
      expect(np['title'], 'Tagged Title', reason: 'snapshot=$np');
      expect((np['duration'] as num?)?.toDouble() ?? 0, greaterThan(1.5),
          reason: 'snapshot=$np',);
      expect(np['playbackState'], 'playing', reason: 'snapshot=$np');
      // Embedded cover only resolves where libmpv is patched for it
      // (macOS desktop). iOS currently ships an unpatched libmpv.
      if (Platform.isMacOS) {
        expect(np['hasArtwork'], true, reason: 'snapshot=$np');
      }
    }, skip: !isApple,);

    testWidgets('play / pause round-trips to the OS playbackState + rate',
        (_) async {
      await player.open(Media(fixture), play: false);
      await player.stream.duration
          .firstWhere((d) => d.inMilliseconds > 2500)
          .timeout(const Duration(seconds: 10));
      await player.setMediaSession(const MediaSession(title: 'E2E'));
      await pumpUntil((s) => s['title'] == 'E2E');

      await player.play();
      await player.stream.playing
          .firstWhere((p) => p)
          .timeout(const Duration(seconds: 5));
      var np = await pumpUntil((s) => s['playbackState'] == 'playing');
      expect((np['rate'] as num?)?.toDouble(), 1.0,
          reason: 'playing must publish rate 1, got ${np['rate']}',);

      await player.pause();
      await player.stream.playing
          .firstWhere((p) => !p)
          .timeout(const Duration(seconds: 5));
      np = await pumpUntil((s) => s['playbackState'] == 'paused');
      expect((np['rate'] as num?)?.toDouble(), 0.0,
          reason: 'paused must publish rate 0, got ${np['rate']}',);
    }, skip: !isApple,);

    testWidgets('seek moves the OS elapsed and keeps the play state',
        (_) async {
      await player.open(Media(fixture), play: false);
      await player.stream.duration
          .firstWhere((d) => d.inMilliseconds > 2500)
          .timeout(const Duration(seconds: 10));
      await player.setMediaSession(const MediaSession(title: 'E2E'));
      await pumpUntil((s) => s['title'] == 'E2E');

      await player.play();
      await player.stream.playing
          .firstWhere((p) => p)
          .timeout(const Duration(seconds: 5));
      await pumpUntil((s) => s['playbackState'] == 'playing');

      await player.seek(const Duration(milliseconds: 1500));
      await player.stream.position
          .firstWhere((p) => p.inMilliseconds >= 1400)
          .timeout(const Duration(seconds: 5));

      // The settled OS state: elapsed moved to ~1.5s, and the play
      // state stayed playing — i.e. mpv's transient pause during the
      // seek did NOT leak to the OS (suppression). The frame-level
      // proof of no-flicker is the Dart controller unit test; here we
      // assert the real settled end-to-end state.
      final np = await pumpUntil(
        (s) => ((s['elapsed'] as num?)?.toDouble() ?? 0) >= 1.4,
      );
      expect(np['playbackState'], 'playing',
          reason: 'seek must not leave the OS paused, got ${np['playbackState']}',);
    }, skip: !isApple,);

    testWidgets('disable clears the OS Now Playing entry', (_) async {
      await player.open(Media(fixture), play: false);
      await player.stream.duration
          .firstWhere((d) => d.inMilliseconds > 2500)
          .timeout(const Duration(seconds: 10));
      await player.setMediaSession(const MediaSession(title: 'E2E'));
      await pumpUntil((s) => s['title'] == 'E2E');

      await player.setMediaSession(null);
      final np = await pumpUntil((s) => s['playbackState'] == 'stopped');
      expect(np['title'], isNull,
          reason: 'disable must clear the title, got ${np['title']}',);
    }, skip: !isApple,);
  });
}
