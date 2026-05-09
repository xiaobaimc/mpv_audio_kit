// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One echo tap of the lavfi `aecho` filter.
///
/// Each tap fires the input signal once, [delayMs] after the source
/// transient, attenuated by [decay]. Several taps in series produce
/// the classic multi-tap echo (think spring reverb fingerprint).
final class AechoTap {
  /// Delay in milliseconds.
  final double delayMs;

  /// Decay factor in `[0, 1]`. `1.0` = no attenuation, `0.5` =
  /// half-amplitude.
  final double decay;

  const AechoTap({required this.delayMs, required this.decay});

  AechoTap copyWith({double? delayMs, double? decay}) =>
      AechoTap(delayMs: delayMs ?? this.delayMs, decay: decay ?? this.decay);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AechoTap &&
          other.delayMs == delayMs &&
          other.decay == decay);

  @override
  int get hashCode => Object.hash(delayMs, decay);

  @override
  String toString() => 'AechoTap(delay: $delayMs ms, decay: $decay)';
}

/// Typed access over the parallel pipe-separated CSVs lavfi's
/// `aecho` packs as `delays`/`decays`.
///
/// The two CSVs are positional: the Nth delay pairs with the Nth
/// decay. Mismatched lengths are clamped to the shorter list — the
/// dropped tail would crash the filter at config time anyway.
extension AechoTapsX on AechoSettings {
  /// Decoded list of taps in declaration order.
  List<AechoTap> get taps {
    final ds = _splitCsv(delays);
    final cs = _splitCsv(decays);
    final n = ds.length < cs.length ? ds.length : cs.length;
    return List.generate(
      n,
      (i) => AechoTap(delayMs: ds[i], decay: cs[i]),
      growable: false,
    );
  }

  /// Returns a copy whose [delays] / [decays] reflect [taps].
  AechoSettings withTaps(List<AechoTap> taps) {
    if (taps.isEmpty) return copyWith(delays: '0', decays: '0');
    return copyWith(
      delays:
          taps.map((t) => t.delayMs.toStringAsFixed(2)).join('|'),
      decays: taps.map((t) => t.decay.toStringAsFixed(3)).join('|'),
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
