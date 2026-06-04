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
/// `[start + i / bins * duration, start + (i + 1) / bins * duration)`.
/// [min] and [max] hold the lowest and highest sample value seen in each
/// bin, range `[-1.0, +1.0]`.
///
/// For a normal (known-length) track [start] is zero and [duration] is the
/// whole track, so bins map onto `[0, duration]`. For a **live** stream
/// ([live] == true) there is no total length: the envelope is a sliding
/// window kept in lockstep with the demuxer's seekable cache, so [start] is
/// the absolute media time of bin 0 (the oldest still-cached moment) and
/// [duration] is the span currently held (it grows while you listen and
/// only drops its oldest bins once the demuxer evicts that audio from its
/// back-buffer). The newest bin is "now". Map bins with [start]/[duration]
/// in absolute media time and you can scrub anywhere the cache still
/// covers.
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
  /// Absolute media time of bin 0. Zero for a normal track; for a [live]
  /// rolling window it's the oldest still-cached moment, so bins sit at
  /// their true media time and seeks land where they're drawn.
  final Duration start;

  /// Duration the bin axis spans. For a normal track this is the whole
  /// track; for a [live] window it's the span currently held (see [start]).
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

  /// True for a live stream of unknown total length: the envelope is a
  /// sliding window anchored to the demuxer cache rather than a fixed
  /// `[0, duration]` track axis (see the class docs and [start]). A renderer
  /// places the playhead at the true playback position (it does NOT pin to
  /// "now" / auto-follow the newest bin) and allows scrubbing only within
  /// `[start, start + duration]`.
  final bool live;

  /// Creates a waveform. Used internally by the waveform pipeline.
  ///
  /// The three per-bin arrays must share one length — the painter indexes
  /// `max[i]` off `min.length` with no per-element guard, so a mismatched
  /// producer would read out of range. The assert makes that contract fail
  /// loudly in debug instead of silently misrendering.
  const WaveformData({
    required this.duration,
    required this.min,
    required this.max,
    required this.filled,
    this.start = Duration.zero,
    this.live = false,
  }) : assert(
          max.length == min.length && filled.length == min.length,
          'WaveformData min/max/filled must share one length',
        );

  /// Number of bins. Convenience accessor — equal to `min.length`.
  int get bins => min.length;

  /// Absolute media time at the end of the bin axis (`start + duration`).
  Duration get end => start + duration;
}
