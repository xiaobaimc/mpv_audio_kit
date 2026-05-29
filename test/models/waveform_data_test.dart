// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:test/test.dart';

void main() {
  group('WaveformData', () {
    test('bins matches min length', () {
      final w = WaveformData(
        duration: const Duration(seconds: 30),
        min: Float32List.fromList(const [-0.5, -0.7, 0.0]),
        max: Float32List.fromList(const [0.4, 0.6, 0.0]),
      );
      expect(w.bins, 3);
      expect(w.min.length, w.max.length);
      expect(w.duration, const Duration(seconds: 30));
      expect(w.min[0], closeTo(-0.5, 1e-6));
      expect(w.max[1], closeTo(0.6, 1e-6));
    });
  });
}
