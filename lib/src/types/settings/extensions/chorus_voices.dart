// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One voice of the lavfi `chorus` filter.
///
/// `chorus` produces a "many singers" effect by mixing the dry input
/// with several delayed, decayed, slowly-detuned copies of itself.
/// Each [ChorusVoice] is one of those copies with its own delay,
/// decay, modulation depth, and modulation rate.
final class ChorusVoice {
  /// Delay in milliseconds (typical chorus range: 30..50 ms).
  final double delayMs;

  /// Decay factor in `[0, 1]`.
  final double decay;

  /// LFO modulation depth in milliseconds.
  final double depthMs;

  /// LFO modulation rate in Hz (typical chorus range: 0.1..1 Hz).
  final double speedHz;

  const ChorusVoice({
    required this.delayMs,
    required this.decay,
    required this.depthMs,
    required this.speedHz,
  });

  ChorusVoice copyWith({
    double? delayMs,
    double? decay,
    double? depthMs,
    double? speedHz,
  }) =>
      ChorusVoice(
        delayMs: delayMs ?? this.delayMs,
        decay: decay ?? this.decay,
        depthMs: depthMs ?? this.depthMs,
        speedHz: speedHz ?? this.speedHz,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChorusVoice &&
          other.delayMs == delayMs &&
          other.decay == decay &&
          other.depthMs == depthMs &&
          other.speedHz == speedHz);

  @override
  int get hashCode => Object.hash(delayMs, decay, depthMs, speedHz);

  @override
  String toString() => 'ChorusVoice(delay: $delayMs ms, decay: $decay, '
      'depth: $depthMs ms, speed: $speedHz Hz)';
}

/// Typed access over the four parallel pipe-separated CSVs
/// (`delays`/`decays`/`depths`/`speeds`) lavfi's `chorus` exposes.
///
/// The four lists are positional: the Nth delay/decay/depth/speed
/// quartet is one voice. Mismatched lengths collapse to the shortest
/// — lavfi rejects asymmetric configs at chain-build time.
extension ChorusVoicesX on ChorusSettings {
  /// Decoded list of voices in declaration order.
  List<ChorusVoice> get voices {
    final ds = _splitCsv(delays);
    final cs = _splitCsv(decays);
    final dp = _splitCsv(depths);
    final sp = _splitCsv(speeds);
    final n = [ds.length, cs.length, dp.length, sp.length]
        .reduce((a, b) => a < b ? a : b);
    return List.generate(
      n,
      (i) => ChorusVoice(
        delayMs: ds[i],
        decay: cs[i],
        depthMs: dp[i],
        speedHz: sp[i],
      ),
      growable: false,
    );
  }

  /// Returns a copy whose four CSVs reflect [voices].
  ChorusSettings withVoices(List<ChorusVoice> voices) {
    if (voices.isEmpty) {
      return copyWith(delays: '', decays: '', depths: '', speeds: '');
    }
    String join(double Function(ChorusVoice) get) =>
        voices.map((v) => get(v).toStringAsFixed(3)).join('|');
    return copyWith(
      delays: join((v) => v.delayMs),
      decays: join((v) => v.decay),
      depths: join((v) => v.depthMs),
      speeds: join((v) => v.speedHz),
    );
  }
}

List<double> _splitCsv(String src) {
  if (src.trim().isEmpty) return const [];
  final out = <double>[];
  for (final part in src.split('|')) {
    final v = double.tryParse(part.trim());
    if (v != null) out.add(v);
  }
  return out;
}
