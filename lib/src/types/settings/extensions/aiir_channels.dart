// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One channel slot of the lavfi `aiir` filter — the per-channel gain
/// plus the polynomial coefficients of its IIR transfer function.
///
/// `aiir` lets the consumer specify a fully custom IIR filter by
/// declaring the numerator (`zeros`) and denominator (`poles`)
/// polynomials per channel; channel order matches the input layout.
/// The format encodes channels separated by `|` and coefficients
/// within a channel separated by spaces.
final class AiirChannel {
  /// Linear gain for this channel.
  final double gain;
  /// Numerator (B / "zeros" / reflection) polynomial coefficients.
  final List<double> zeros;
  /// Denominator (A / "poles" / ladder) polynomial coefficients.
  final List<double> poles;

  const AiirChannel({
    required this.gain,
    required this.zeros,
    required this.poles,
  });

  AiirChannel copyWith({
    double? gain,
    List<double>? zeros,
    List<double>? poles,
  }) =>
      AiirChannel(
        gain: gain ?? this.gain,
        zeros: zeros ?? this.zeros,
        poles: poles ?? this.poles,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiirChannel &&
          other.gain == gain &&
          _listEq(other.zeros, zeros) &&
          _listEq(other.poles, poles));

  @override
  int get hashCode => Object.hash(
      gain, Object.hashAll(zeros), Object.hashAll(poles));

  @override
  String toString() =>
      'AiirChannel(gain: $gain, zeros: $zeros, poles: $poles)';
}

bool _listEq(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Typed access over `aiir`'s three parallel string parameters
/// (`gains`/`k`, `poles`/`p`, `zeros`/`z`). The Nth `|`-section of
/// each string belongs to the Nth output channel; coefficient lists
/// within a channel are space-separated.
///
/// The extension always reads / writes the long-form param names
/// (`gains`, `poles`, `zeros`); the short aliases (`k`, `p`, `z`) are
/// kept untouched on writes — consumers using both would conflict
/// with themselves anyway.
extension AiirChannelsX on AiirSettings {
  /// Decoded channel slots in declaration order. When the three
  /// underlying CSVs differ in length, the shortest list wins (lavfi
  /// rejects asymmetric configs at chain-build time).
  List<AiirChannel> get channels {
    final g = _splitChannelsCsv(gains);
    final z = _splitChannelsListCsv(zeros);
    final p = _splitChannelsListCsv(poles);
    final n = [g.length, z.length, p.length]
        .reduce((a, b) => a < b ? a : b);
    return List.generate(
      n,
      (i) => AiirChannel(gain: g[i], zeros: z[i], poles: p[i]),
      growable: false,
    );
  }

  /// Returns a copy whose three CSV strings reflect [channels].
  AiirSettings withChannels(List<AiirChannel> channels) {
    if (channels.isEmpty) {
      return copyWith(gains: '', zeros: '', poles: '');
    }
    String join(List<double> Function(AiirChannel) get, String inner) =>
        channels
            .map((c) => get(c).map((v) => v.toStringAsFixed(4)).join(inner))
            .join('|');
    return copyWith(
      gains:
          channels.map((c) => c.gain.toStringAsFixed(4)).join('|'),
      zeros: join((c) => c.zeros, ' '),
      poles: join((c) => c.poles, ' '),
    );
  }
}

List<double> _splitChannelsCsv(String src) {
  if (src.trim().isEmpty) return const [];
  final out = <double>[];
  for (final part in src.split('|')) {
    final v = double.tryParse(part.trim());
    if (v != null) out.add(v);
  }
  return out;
}

List<List<double>> _splitChannelsListCsv(String? src) {
  if (src == null || src.trim().isEmpty) return const [];
  final out = <List<double>>[];
  for (final ch in src.split('|')) {
    final coeffs = <double>[];
    for (final tok in ch.trim().split(RegExp(r'\s+'))) {
      final v = double.tryParse(tok);
      if (v != null) coeffs.add(v);
    }
    out.add(coeffs);
  }
  return out;
}
