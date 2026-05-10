// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

WaveformLevel _buildLevel(int pps, List<double> min, List<double> max) =>
    WaveformLevel(
      peaksPerSecond: pps,
      min: Float32List.fromList(min),
      max: Float32List.fromList(max),
    );

void main() {
  group('WaveformLevel', () {
    test('bins matches min length', () {
      final level = _buildLevel(10, const [-0.5, -0.7, 0.0], const [0.4, 0.6, 0.0]);
      expect(level.bins, 3);
      expect(level.min.length, level.max.length);
      expect(level.peaksPerSecond, 10);
      expect(level.min[0], closeTo(-0.5, 1e-6));
      expect(level.max[1], closeTo(0.6, 1e-6));
    });
  });

  group('WaveformData', () {
    test('exposes coarse / medium / fine accessors', () {
      final w = WaveformData(
        sourceDuration: const Duration(seconds: 30),
        sampleRate: 44100,
        levels: [
          _buildLevel(1, const [-0.5], const [0.5]),
          _buildLevel(10, const [-0.6, -0.7], const [0.6, 0.7]),
          _buildLevel(400, const [-0.8, -0.9, -1.0], const [0.8, 0.9, 1.0]),
        ],
      );
      expect(w.sourceDuration, const Duration(seconds: 30));
      expect(w.sampleRate, 44100);
      expect(w.coarse.peaksPerSecond, 1);
      expect(w.medium.peaksPerSecond, 10);
      expect(w.fine.peaksPerSecond, 400);
      expect(w.medium.bins, 2);
    });

    test('bestLevelForPeaksPerSecond picks the lowest matching density',
        () {
      final w = WaveformData(
        sourceDuration: const Duration(seconds: 30),
        sampleRate: 44100,
        levels: [
          _buildLevel(1, const [0], const [0]),
          _buildLevel(10, const [0], const [0]),
          _buildLevel(400, const [0], const [0]),
        ],
      );
      expect(w.bestLevelForPeaksPerSecond(0.5).peaksPerSecond, 1);
      expect(w.bestLevelForPeaksPerSecond(5).peaksPerSecond, 10);
      expect(w.bestLevelForPeaksPerSecond(50).peaksPerSecond, 400);
      // Beyond fine — should fall back to fine, consumer is expected
      // to switch to readWaveformRegion at this point.
      expect(w.bestLevelForPeaksPerSecond(10000).peaksPerSecond, 400);
    });
  });
}
