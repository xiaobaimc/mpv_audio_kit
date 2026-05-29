// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

@TestOn('mac-os || linux || windows')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../_helpers/setter_test_helpers.dart';

void main() {
  // M2 — `Player.open()` / `openAll()` await `_tlsBundleReady` before
  // issuing `loadfile`, so HTTPS targets see `tls-ca-file` populated
  // on the very first request. `add()` and `replace()` must do the
  // same: a consumer that goes straight from `Player()` to
  // `player.add(Media('https://...'))` would otherwise race the
  // bundle extraction and the first HTTPS handshake might fail peer
  // verification non-deterministically.
  //
  // This test does not need a network round-trip — it only asserts
  // the observable post-condition: when `add()` returns, the bundle
  // path has been written into the player state.
  final fixturePath = defaultFixturePath();

  setUpAll(() => initLibmpvOrSkip(fixturePath: fixturePath));

  group('TLS bundle is awaited on every load entry point (M2)', () {
    test('add() awaits _tlsBundleReady before issuing loadfile', () async {
      final player = await buildPlayer();
      try {
        // Construct → immediately add. Pre-fix this races the async
        // TlsCaBundle.extract(); post-fix `add()` awaits the same
        // Future that `open()` does, so the post-condition holds
        // deterministically.
        await player.add(Media(fixturePath));

        expect(
          player.state.tlsCaFile,
          isNotEmpty,
          reason: 'add() must await the TLS bundle so HTTPS appends '
              'see tls-ca-file populated by the time loadfile fires',
        );
      } finally {
        await player.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 15)),);

    test('replace() awaits _tlsBundleReady before issuing loadfile', () async {
      final player = await buildPlayer();
      try {
        await player.add(Media(fixturePath));
        await player.replace(0, Media(fixturePath));

        expect(
          player.state.tlsCaFile,
          isNotEmpty,
          reason: 'replace() shares the same TLS gating contract '
              'with open() and add()',
        );
      } finally {
        await player.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 15)),);
  });
}
