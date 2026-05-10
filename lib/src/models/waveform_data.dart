// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

/// One resolution level of a [WaveformData] mipmap pyramid.
///
/// Each level stores the min/max envelope of the source audio at a
/// specific peaks-per-second density. Bin `i` covers the time slice
/// `[i / peaksPerSecond, (i + 1) / peaksPerSecond)` from the start of
/// the track.
///
/// Three levels are typically present on a [WaveformData] returned by
/// the player: coarse (~1 pps, full-track overview), medium (~10 pps,
/// default zoom), fine (~400 pps, moderate zoom). For deeper zoom
/// (sample-level), consumers fall through to
/// [Player.readWaveformRegion].
final class WaveformLevel {
  /// Effective peaks-per-second density of this level. Lower than the
  /// requested target when the analyzer hit its per-level bin cap on
  /// very long tracks.
  final int peaksPerSecond;

  /// Lowest sample value observed in each bin, range `[-1.0, +1.0]`.
  /// Length matches [max].
  final Float32List min;

  /// Highest sample value observed in each bin, range `[-1.0, +1.0]`.
  final Float32List max;

  /// Creates a level. Used internally by the waveform pipeline.
  const WaveformLevel({
    required this.peaksPerSecond,
    required this.min,
    required this.max,
  });

  /// Number of bins. Convenience accessor — equal to `min.length`.
  int get bins => min.length;
}

/// Mipmap min/max envelope of the audio currently loaded.
///
/// Emitted on [PlayerStream.waveform] once the engine finishes
/// bulk-decoding the file in the background — typically tens to a
/// few hundred milliseconds after `loadfile`. The waveform is mixed
/// down to mono (mean of channels) and binned at multiple resolution
/// levels in a single decode pass.
///
/// Levels (in [levels] order):
///   1. **coarse** — ~1 peak per second; full-track overview thumbs
///   2. **medium** — ~10 peaks per second; default player view
///   3. **fine**   — ~400 peaks per second; moderate zoom
///
/// For deeper zoom (sample-level), use [Player.readWaveformRegion]
/// which decodes a specific time range to raw mono Float32 PCM.
///
/// Example — paint a bar per medium-level bin with a played-region
/// highlight:
///
/// ```dart
/// player.stream.waveform.listen((wave) {
///   if (wave == null) return;
///   final level = wave.medium;
///   for (var i = 0; i < level.bins; i++) {
///     final yMin = level.min[i] * canvasHeight / 2;
///     final yMax = level.max[i] * canvasHeight / 2;
///     // draw bar i from yMin to yMax …
///   }
/// });
/// ```
///
/// Example — pick the best level for a given samples-per-pixel zoom:
///
/// ```dart
/// final level = wave.bestLevelForPeaksPerSecond(
///   wave.sampleRate / samplesPerPixel,
/// );
/// ```
final class WaveformData {
  /// Duration the bin axis maps to. Multiply `i / level.bins` by this
  /// to get the timestamp at the start of bin `i` for any level.
  final Duration sourceDuration;

  /// Source sample rate of the analyzed audio (Hz). Used by
  /// [bestLevelForPeaksPerSecond] to convert samples-per-pixel into a
  /// peaks-per-second target.
  final int sampleRate;

  /// Mipmap levels, ordered coarsest to finest.
  final List<WaveformLevel> levels;

  /// Creates a waveform. Used internally by the waveform pipeline.
  const WaveformData({
    required this.sourceDuration,
    required this.sampleRate,
    required this.levels,
  });

  /// Coarsest level (~1 peak / second). Overview at thumbnail size.
  WaveformLevel get coarse => levels[0];

  /// Medium level (~10 peaks / second). Default player-view density.
  WaveformLevel get medium => levels[1];

  /// Finest level (~400 peaks / second). Moderate zoom.
  WaveformLevel get fine => levels[2];

  /// Picks the lowest-density level whose [WaveformLevel.peaksPerSecond]
  /// meets or exceeds the requested target. Falls back to [fine] when
  /// no level is dense enough — at that point the consumer should
  /// switch to [Player.readWaveformRegion] for true sample-level
  /// rendering.
  WaveformLevel bestLevelForPeaksPerSecond(double targetPeaksPerSecond) {
    for (final level in levels) {
      if (level.peaksPerSecond >= targetPeaksPerSecond) return level;
    }
    return levels.last;
  }
}
