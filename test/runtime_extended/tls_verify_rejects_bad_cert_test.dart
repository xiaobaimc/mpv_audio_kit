// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.
//
// The TLS-verification negative path. A clean handshake against a valid
// certificate only proves verification did not break a good connection;
// it does not prove verification *rejects* a bad one. badssl.com publishes
// endpoints with deliberately invalid certificates for exactly this check.

@TestOn('mac-os || linux || windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../_helpers/libmpv_resolver.dart';
import '../_helpers/setter_test_helpers.dart';

void main() {
  // self-signed.badssl.com presents a certificate signed by no trusted
  // root — `tls-verify` on must reject it, off must let it through. The
  // group skips when the host has no internet, mirroring streaming_test.
  const badCertUrl = 'https://self-signed.badssl.com/';
  const probeHost = 'https://badssl.com/';

  bool networkAvailable = false;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final lib = resolveLibmpv();
    if (lib == null) {
      markTestSkipped('libmpv not found');
      return;
    }
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final req = await client.headUrl(Uri.parse(probeHost));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain();
      client.close();
      networkAvailable = true;
    } catch (_) {
      networkAvailable = false;
    }
    MpvAudioKit.ensureInitialized(libmpv: lib, hotRestartCleanup: false);
  });

  group('TLS verify rejects an invalid certificate', () {
    late Player player;

    setUpAll(() async {
      if (!networkAvailable) return;
      // warn surfaces mpv's certificate-verification error on stream.log.
      player = await buildPlayer(
        configuration: const PlayerConfiguration(
          autoPlay: false,
          logLevel: LogLevel.warn,
        ),
      );
    });

    tearDownAll(() async {
      if (!networkAvailable) return;
      await player.stop();
      await player.dispose();
    });

    // Opens the bad-certificate URL, waits for the load to resolve, and
    // returns every log line mentioning a certificate — the fingerprint
    // of a TLS verification failure.
    Future<List<String>> openAndCollectCertErrors() async {
      final certErrors = <String>[];
      final logSub = player.stream.log.listen((e) {
        if (e.text.toLowerCase().contains('certificate')) {
          certErrors.add('[${e.prefix}] ${e.text}');
        }
      });
      final ended = Completer<void>();
      final endSub = player.stream.endFile.listen((_) {
        if (!ended.isCompleted) ended.complete();
      });
      try {
        await player.open(Media(badCertUrl), play: false);
        await ended.future
            .timeout(const Duration(seconds: 20), onTimeout: () {});
        // Grace window so a trailing error log line is still captured.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } finally {
        await logSub.cancel();
        await endSub.cancel();
      }
      return certErrors;
    }

    test('tls-verify on → the self-signed certificate is rejected', () async {
      if (!networkAvailable) {
        markTestSkipped('Network unreachable');
        return;
      }
      await player.setTlsVerify(true);
      final certErrors = await openAndCollectCertErrors();
      expect(certErrors, isNotEmpty,
          reason: 'with tls-verify on, mpv must reject the self-signed '
              'certificate and log a verification failure');
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('tls-verify off → the handshake is not rejected at the TLS layer',
        () async {
      if (!networkAvailable) {
        markTestSkipped('Network unreachable');
        return;
      }
      await player.setTlsVerify(false);
      final certErrors = await openAndCollectCertErrors();
      expect(certErrors, isEmpty,
          reason: 'with tls-verify off, the handshake completes — any '
              'failure is at the demuxer, not a certificate rejection: '
              '$certErrors');
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
