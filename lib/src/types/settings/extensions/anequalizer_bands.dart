// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One logical band of the lavfi `anequalizer` filter.
///
/// On the wire this is repeated once per channel inside the
/// `params` CSV — the typed model hides that detail. Stereo content
/// hears the band on both channels by default; surround content past
/// channel 1 is left to mpv's downmix.
final class AnequalizerBand {
  /// Centre frequency in Hz.
  final double frequency;

  /// Bandwidth in Hz (NOT a Q-factor). Use [withQ] to set by Q.
  final double bandwidth;

  /// Gain in dB.
  final double gain;

  /// Filter shape. Defaults to [AnequalizerBandType.butterworth] —
  /// matches the lavfi `t=0` default.
  final AnequalizerBandType type;

  const AnequalizerBand({
    required this.frequency,
    required this.bandwidth,
    required this.gain,
    this.type = AnequalizerBandType.butterworth,
  });

  /// Q-factor view. `Q = frequency / bandwidth`.
  double get q => bandwidth <= 0 ? 1.0 : frequency / bandwidth;

  /// Returns a copy with [bandwidth] derived from a Q-factor.
  AnequalizerBand withQ(double q) =>
      copyWith(bandwidth: frequency / q.clamp(0.001, 1000.0));

  AnequalizerBand copyWith({
    double? frequency,
    double? bandwidth,
    double? gain,
    AnequalizerBandType? type,
  }) =>
      AnequalizerBand(
        frequency: frequency ?? this.frequency,
        bandwidth: bandwidth ?? this.bandwidth,
        gain: gain ?? this.gain,
        type: type ?? this.type,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnequalizerBand &&
          other.frequency == frequency &&
          other.bandwidth == bandwidth &&
          other.gain == gain &&
          other.type == type);

  @override
  int get hashCode => Object.hash(frequency, bandwidth, gain, type);

  @override
  String toString() =>
      'AnequalizerBand(frequency: $frequency, bandwidth: $bandwidth, '
      'gain: $gain, type: $type)';
}

/// lavfi `anequalizer` filter shape. Matches `t=0|1|2` on the wire.
enum AnequalizerBandType {
  butterworth(0),
  chebyshev1(1),
  chebyshev2(2);

  final int wireValue;
  const AnequalizerBandType(this.wireValue);

  static AnequalizerBandType fromWire(int v) => switch (v) {
        1 => chebyshev1,
        2 => chebyshev2,
        _ => butterworth,
      };
}

/// Default channel count covered by [AnequalizerBandsX.withBands]. Two
/// channels (L+R) is the canonical stereo case; surround content is
/// left to mpv's automatic downmix.
const int _defaultChannels = 2;

/// Typed access over the raw `params` CSV held by [AnequalizerSettings].
extension AnequalizerBandsX on AnequalizerSettings {
  /// Decoded list of bands. Reads the underlying [params] string —
  /// per-channel duplication is collapsed (we treat distinct bands as
  /// distinct only when their frequency / bandwidth / gain / type
  /// tuple differs).
  List<AnequalizerBand> get bands => _parseAnequalizerBands(params);

  /// Returns a copy whose [params] reflects [bands]. Each band is
  /// emitted once per channel up to [channels] (defaults to 2 — stereo)
  /// so signals get the band on every channel mpv can downmix to.
  AnequalizerSettings withBands(
    List<AnequalizerBand> bands, {
    int channels = _defaultChannels,
  }) =>
      copyWith(params: _serializeAnequalizerBands(bands, channels: channels));
}

// Parser tolerates the codegen's `[...]` wrap (added for mpv's filter-
// args escape) as well as the bare CSV form.
final RegExp _bandRe = RegExp(
  r'c(\d+)\s+f=([0-9.eE+-]+)\s+w=([0-9.eE+-]+)\s+g=([0-9.eE+-]+)'
  r'(?:\s+t=(\d+))?',
);

List<AnequalizerBand> _parseAnequalizerBands(String params) {
  var raw = params.trim();
  if (raw.isEmpty) return const [];
  if (raw.startsWith('[') && raw.endsWith(']')) {
    raw = raw.substring(1, raw.length - 1);
  }
  // Deduplicate by (f, w, g, t): the same logical band emitted on
  // multiple channels should collapse to a single typed entry.
  final seen = <String, AnequalizerBand>{};
  for (final entry in raw.split('|')) {
    final s = entry.trim();
    if (s.isEmpty) continue;
    final m = _bandRe.firstMatch(s);
    if (m == null) continue;
    final f = double.tryParse(m.group(2)!);
    final w = double.tryParse(m.group(3)!);
    final g = double.tryParse(m.group(4)!);
    final t = int.tryParse(m.group(5) ?? '0') ?? 0;
    if (f == null || w == null || g == null) continue;
    final key = '$f|$w|$g|$t';
    seen[key] = AnequalizerBand(
      frequency: f,
      bandwidth: w,
      gain: g,
      type: AnequalizerBandType.fromWire(t),
    );
  }
  return seen.values.toList(growable: false);
}

String _serializeAnequalizerBands(
  List<AnequalizerBand> bands, {
  required int channels,
}) {
  if (bands.isEmpty) return '';
  if (channels < 1) channels = 1;
  final out = <String>[];
  for (final b in bands) {
    for (var ch = 0; ch < channels; ch++) {
      out.add(
        'c$ch f=${b.frequency.toStringAsFixed(2)} '
        'w=${b.bandwidth.toStringAsFixed(2)} '
        'g=${b.gain.toStringAsFixed(2)} '
        't=${b.type.wireValue}',
      );
    }
  }
  return out.join('|');
}
