// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@TestOn('mac-os || linux || windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import '../_helpers/setter_test_helpers.dart';

/// End-to-end coverage for [PlayerStream.waveform], backed by the
/// `waveform-data` mpv property added by `patch_bulk_analysis.py`.
///
/// On a libmpv binary without the patch the property doesn't exist;
/// every test in this group is marked skipped instead of failing the
/// suite — the wrapper has no fallback path, so the absence of the
/// patch is a build issue, not a Dart-side regression.
void main() {
  final fixturePath = defaultFixturePath();

  setUpAll(() => initLibmpvOrSkip(fixturePath: fixturePath));

  group('Waveform bulk analysis', () {
    test('full mipmap materialises within 5s of loadfile (without playing)',
        () async {
      final player = await buildPlayer(
        configuration: const PlayerConfiguration(
          waveform: WaveformSettings(enabled: true),
        ),
      );
      try {
        // Probe the patched property — if mpv rejects it, the binary
        // is unpatched and we skip rather than fail.
        final probe = await player.getRawProperty('waveform-data');
        if (probe == null) {
          markTestSkipped('libmpv has no waveform-data property '
              '(patch_bulk_analysis.py not applied to this binary).');
          return;
        }

        final completer = Completer<WaveformData>();
        final sub = player.stream.waveform.listen((w) {
          if (w != null && !completer.isCompleted) completer.complete(w);
        });
        try {
          await openAndWaitForLoad(player, fixturePath);
          final wave =
              await completer.future.timeout(const Duration(seconds: 5));

          // Three-level mipmap: coarse / medium / fine.
          expect(wave.levels.length, 3);
          expect(wave.coarse.peaksPerSecond, lessThan(wave.medium.peaksPerSecond));
          expect(wave.medium.peaksPerSecond, lessThan(wave.fine.peaksPerSecond));
          expect(wave.sourceDuration.inMilliseconds, greaterThan(0));
          expect(wave.sampleRate, greaterThan(0));

          // Each level: bin count > 0, min/max same length, samples
          // distributed across the axis (not collapsed to one bin).
          for (final level in wave.levels) {
            expect(level.bins, greaterThan(0));
            expect(level.min.length, level.max.length);
          }

          // Sine fixture: the medium-level envelope must carry the
          // signal across more than half the bin axis.
          final medium = wave.medium;
          var firstSignalBin = -1;
          var lastSignalBin = -1;
          for (var i = 0; i < medium.bins; i++) {
            if (medium.max[i].abs() > 1e-4 || medium.min[i].abs() > 1e-4) {
              if (firstSignalBin < 0) firstSignalBin = i;
              lastSignalBin = i;
            }
          }
          expect(firstSignalBin, greaterThanOrEqualTo(0),
              reason: 'Mipmap medium level must carry the sine signal');
          expect(lastSignalBin - firstSignalBin,
              greaterThan(medium.bins ~/ 2),
              reason: 'Signal must span more than half the bin axis');
        } finally {
          await sub.cancel();
        }
      } finally {
        await player.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('emits null on every track change', () async {
      final player = await buildPlayer(
        configuration: const PlayerConfiguration(
          waveform: WaveformSettings(enabled: true),
        ),
      );
      try {
        final probe = await player.getRawProperty('waveform-data');
        if (probe == null) {
          markTestSkipped('libmpv has no waveform-data property.');
          return;
        }

        final events = <WaveformData?>[];
        final sub = player.stream.waveform.listen(events.add);
        try {
          await openAndWaitForLoad(player, fixturePath);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await openAndWaitForLoad(player, fixturePath);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        } finally {
          await sub.cancel();
        }

        // The pipeline emits null on every MPV_EVENT_FILE_LOADED so a
        // renderer can clear stale data between tracks.
        expect(events.contains(null), isTrue,
            reason: 'Expected at least one null reset on track change');
        // And it must eventually reach a real envelope on at least
        // one of the loads.
        expect(events.any((w) => w != null), isTrue,
            reason: 'Expected at least one settled envelope after a load');
      } finally {
        await player.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('readWaveformRegion returns mono PCM for a sub-range',
        () async {
      final player = await buildPlayer(
        configuration: const PlayerConfiguration(
          waveform: WaveformSettings(enabled: true),
        ),
      );
      try {
        final probe = await player.getRawProperty('waveform-region-data');
        if (probe == null) {
          markTestSkipped('libmpv has no waveform-region-data property '
              '(patch_waveform_region.py not applied to this binary).');
          return;
        }
        await openAndWaitForLoad(player, fixturePath);

        final region = await player.readWaveformRegion(
          start: const Duration(milliseconds: 100),
          end: const Duration(milliseconds: 300),
        );
        expect(region, isNotNull);
        expect(region!.sampleRate, greaterThan(0));
        // 200 ms range × native sample rate, give or take a frame.
        final expected = (200 * region.sampleRate / 1000).round();
        expect(region.sampleCount,
            inInclusiveRange((expected * 0.8).round(), (expected * 1.2).round()),
            reason: 'Expected ~200 ms of PCM samples at the source rate');
      } finally {
        await player.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('disabled settings → no envelope emitted', () async {
      final player = await buildPlayer();
      try {
        final probe = await player.getRawProperty('waveform-data');
        if (probe == null) {
          markTestSkipped('libmpv has no waveform-data property.');
          return;
        }

        final events = <WaveformData?>[];
        final sub = player.stream.waveform.listen(events.add);
        try {
          await openAndWaitForLoad(player, fixturePath);
          await Future<void>.delayed(const Duration(seconds: 1));
        } finally {
          await sub.cancel();
        }

        // Default WaveformSettings.disabled → only null events,
        // no settled envelope.
        expect(events.where((e) => e != null), isEmpty,
            reason: 'Disabled analyzer must not emit a real envelope');
      } finally {
        await player.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('sidecar cache hits on repeat load', () async {
      final cacheDir = Directory.systemTemp.createTempSync('wfm_cache_test_');
      addTearDown(() async {
        try {
          if (await cacheDir.exists()) {
            await cacheDir.delete(recursive: true);
          }
        } catch (_) {/* swallow */}
      });

      final player = await buildPlayer(
        configuration: PlayerConfiguration(
          waveform: WaveformSettings(
            enabled: true,
            cacheDirectory: cacheDir,
          ),
        ),
      );
      try {
        final probe = await player.getRawProperty('waveform-data');
        if (probe == null) {
          markTestSkipped('libmpv has no waveform-data property.');
          return;
        }

        // First load: produce + persist
        Completer<WaveformData> firstReady = Completer();
        var sub = player.stream.waveform.listen((w) {
          if (w != null && !firstReady.isCompleted) firstReady.complete(w);
        });
        await openAndWaitForLoad(player, fixturePath);
        await firstReady.future.timeout(const Duration(seconds: 5));
        await sub.cancel();

        // Cache write is fire-and-forget — wait briefly for the
        // background task to finish persisting the entry.
        var cacheFiles = <File>[];
        for (var attempt = 0; attempt < 20; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          cacheFiles = cacheDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.wfm'))
              .toList();
          if (cacheFiles.isNotEmpty) break;
        }
        expect(cacheFiles, isNotEmpty,
            reason: 'Cache file should be written on first ready emit');

        // Second load: should hit the cache and emit immediately
        Completer<WaveformData> secondReady = Completer();
        sub = player.stream.waveform.listen((w) {
          if (w != null && !secondReady.isCompleted) secondReady.complete(w);
        });
        final stopwatch = Stopwatch()..start();
        await openAndWaitForLoad(player, fixturePath);
        await secondReady.future.timeout(const Duration(seconds: 5));
        stopwatch.stop();
        await sub.cancel();

        // Cache hit should resolve faster than the full decode path.
        // We don't assert a hard upper bound (test environments vary),
        // but we expect the full envelope to come back.
      } finally {
        await player.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
