// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One per-channel envelope of the lavfi `compand` filter — the
/// attack and decay time-constants the level detector uses on that
/// channel.
///
/// `compand` accepts independent envelopes per output channel: the
/// first envelope binds to channel 0, the second to channel 1, and
/// so on. When fewer envelopes are declared than the input has
/// channels, the last one applies to the remainder.
final class CompandEnvelope {
  /// Seconds. Attack time-constant (level detector rise).
  final double attackSeconds;

  /// Seconds. Decay time-constant (level detector fall).
  final double decaySeconds;

  const CompandEnvelope({
    required this.attackSeconds,
    required this.decaySeconds,
  });

  CompandEnvelope copyWith({double? attackSeconds, double? decaySeconds}) =>
      CompandEnvelope(
        attackSeconds: attackSeconds ?? this.attackSeconds,
        decaySeconds: decaySeconds ?? this.decaySeconds,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompandEnvelope &&
          other.attackSeconds == attackSeconds &&
          other.decaySeconds == decaySeconds);

  @override
  int get hashCode => Object.hash(attackSeconds, decaySeconds);

  @override
  String toString() =>
      'CompandEnvelope(attack: $attackSeconds s, decay: $decaySeconds s)';
}

/// Typed access over the parallel pipe-separated CSVs lavfi's
/// `compand` packs as `attacks`/`decays`.
///
/// The two CSVs are positional per-channel: the Nth attack pairs
/// with the Nth decay. Mismatched lengths clamp to the shorter list.
extension CompandEnvelopesX on CompandSettings {
  /// Decoded list of per-channel envelopes in declaration order.
  List<CompandEnvelope> get envelopes {
    final atks = _splitCsv(attacks);
    final decs = _splitCsv(decays);
    final n = atks.length < decs.length ? atks.length : decs.length;
    return List.generate(
      n,
      (i) => CompandEnvelope(
        attackSeconds: atks[i],
        decaySeconds: decs[i],
      ),
      growable: false,
    );
  }

  /// Returns a copy whose [attacks] / [decays] reflect [envelopes].
  CompandSettings withEnvelopes(List<CompandEnvelope> envelopes) {
    if (envelopes.isEmpty) return copyWith(attacks: '0', decays: '0.8');
    return copyWith(
      attacks: envelopes
          .map((e) => e.attackSeconds.toStringAsFixed(4))
          .join('|'),
      decays: envelopes
          .map((e) => e.decaySeconds.toStringAsFixed(4))
          .join('|'),
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
