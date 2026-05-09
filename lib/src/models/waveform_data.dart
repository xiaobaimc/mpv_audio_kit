// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

/// Mono min/max envelope of the audio currently loaded, binned across
/// the track duration.
///
/// Emitted on [PlayerStream.waveform] once the engine finishes
/// bulk-decoding the file in the background — typically tens to a few
/// hundred milliseconds after `loadfile`. Each entry of [min] / [max]
/// is the lowest / highest sample value (range `[-1.0, +1.0]`)
/// observed inside one time bin (a slice of the track of duration
/// `sourceDuration / min.length`). Multi-channel input is mixed down
/// to mono (mean of channels) before binning.
///
/// Example — paint a bar per bin with a played-region highlight:
///
/// ```dart
/// player.stream.waveform.listen((wave) {
///   if (wave == null) return;
///   for (var i = 0; i < wave.min.length; i++) {
///     final yMin = wave.min[i] * canvasHeight / 2;
///     final yMax = wave.max[i] * canvasHeight / 2;
///     // draw bar i from yMin to yMax …
///   }
/// });
/// ```
class WaveformData {
  /// Creates a frame. Only used internally by the waveform pipeline.
  const WaveformData({
    required this.min,
    required this.max,
    required this.sourceDuration,
  });

  /// Lowest sample value observed in each bin, range `[-1.0, +1.0]`.
  /// Length matches [max]. Bin `i` covers
  /// `i * sourceDuration / length` to `(i + 1) * sourceDuration / length`.
  final Float32List min;

  /// Highest sample value observed in each bin, range `[-1.0, +1.0]`.
  final Float32List max;

  /// Duration the bin axis maps to. Multiply `i / length` by this to
  /// get the timestamp at the start of bin `i`.
  final Duration sourceDuration;

  /// Number of bins. Convenience accessor — equal to `min.length`.
  int get bins => min.length;
}
