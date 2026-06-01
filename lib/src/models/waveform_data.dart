// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

/// Mono min/max amplitude envelope of the audio currently loaded.
///
/// Emitted once per track on [PlayerStream.waveform] after the engine
/// finishes decoding the file in the background. The track is mixed
/// down to mono and binned into a fixed ~2000-entry envelope.
///
/// Bin `i` spans the time slice
/// `[i / bins * duration, (i + 1) / bins * duration)` from the start
/// of the track. [min] and [max] hold the lowest and highest sample
/// value seen in each bin, range `[-1.0, +1.0]`.
///
/// Example — paint a bar per bin:
///
/// ```dart
/// player.stream.waveform.listen((wave) {
///   if (wave == null) return;
///   for (var i = 0; i < wave.bins; i++) {
///     final yMin = wave.min[i] * canvasHeight / 2;
///     final yMax = wave.max[i] * canvasHeight / 2;
///     // draw bar i from yMin to yMax …
///   }
/// });
/// ```
final class WaveformData {
  /// Duration the bin axis spans — the full length of the track.
  final Duration duration;

  /// Per-bin minimum sample value, range `[-1.0, +1.0]`. Length
  /// matches [max].
  final Float32List min;

  /// Per-bin maximum sample value, range `[-1.0, +1.0]`.
  final Float32List max;

  /// Per-bin coverage flag (one byte per bin, length matches [min]): `1`
  /// for a bin that has real data, `0` for one not yet covered.
  ///
  /// For a fully-analysed (local-file) waveform every bin is `1`. For a
  /// progressively-grown one (network / transcode streams, filled as
  /// playback advances) bins ahead of the playhead — or skipped by a seek
  /// — are `0`, so a renderer can draw them as a baseline instead of a
  /// misleading flat-zero spike.
  final Uint8List filled;

  /// Creates a waveform. Used internally by the waveform pipeline.
  const WaveformData({
    required this.duration,
    required this.min,
    required this.max,
    required this.filled,
  });

  /// Number of bins. Convenience accessor — equal to `min.length`.
  int get bins => min.length;
}
