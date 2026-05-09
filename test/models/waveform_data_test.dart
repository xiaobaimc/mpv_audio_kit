// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

void main() {
  group('WaveformData', () {
    test('bins matches min length, fields readable', () {
      final w = WaveformData(
        min: Float32List.fromList(const [-0.5, -0.7, 0.0]),
        max: Float32List.fromList(const [0.4, 0.6, 0.0]),
        sourceDuration: const Duration(seconds: 30),
      );
      expect(w.bins, 3);
      expect(w.min.length, w.max.length);
      expect(w.sourceDuration, const Duration(seconds: 30));
      // Float32 — compare with tolerance, not literal equality.
      expect(w.min[0], closeTo(-0.5, 1e-6));
      expect(w.max[1], closeTo(0.6, 1e-6));
    });
  });
}
