// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

/// Raw mono Float32 PCM samples for a contiguous time range of the
/// currently-loaded track.
///
/// Returned by [Player.readWaveformRegion]. Used for sample-level
/// zoom rendering — when the consumer is zoomed in past the density
/// of the deepest mipmap level on [PlayerStream.waveform], it reads a
/// region of true PCM samples and draws each one as a dot connected
/// by lines to its neighbours.
///
/// Channel layout: mono (mean of input channels). For interleaved
/// multi-channel raw PCM, run a custom decode pass.
final class WaveformRegion {
  /// Start of the decoded range (echoed back from the request — may
  /// differ slightly from the requested value if the codec only
  /// supports keyframe-aligned seeks).
  final Duration start;

  /// End of the decoded range.
  final Duration end;

  /// Source sample rate, e.g. 44100 / 48000 Hz.
  final int sampleRate;

  /// Raw mono PCM samples, length = `(end - start) * sampleRate`
  /// (modulo the rounding above). Range `[-1.0, +1.0]`.
  final Float32List samples;

  const WaveformRegion({
    required this.start,
    required this.end,
    required this.sampleRate,
    required this.samples,
  });

  /// Number of samples. Convenience accessor — equal to
  /// `samples.length`.
  int get sampleCount => samples.length;
}
