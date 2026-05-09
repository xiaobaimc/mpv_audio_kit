// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// 18 fixed band centre frequencies of the lavfi `superequalizer`,
/// in Hz, lows-to-highs in declaration order. The frequencies are
/// hard-coded inside `af_superequalizer.c` and are not configurable —
/// only the per-band gain is.
const List<double> kSuperequalizerFrequencies = [
  65, 92, 131, 185, 262, 370, 523, 740,
  1047, 1480, 2093, 2960, 4186, 5920,
  8372, 11840, 16744, 20000,
];

/// Number of bands the `superequalizer` filter exposes — fixed by
/// the underlying ISO half-octave grid.
const int kSuperequalizerBandCount = 18;

/// Default linear gain for an unmodified band (1.0 = unity, no
/// change to that frequency's level).
const double kSuperequalizerUnityGain = 1.0;

/// Typed access over the digit-prefixed `1b`, `2b`, …, `18b`
/// parameters that lavfi's `superequalizer` packs into the bundle's
/// raw `params: Map<String, double>`.
///
/// Each band is a linear amplitude factor in `[0, 20]` where `1.0`
/// is unity. Display-side (UI sliders, knobs) typically convert to
/// dB via `20·log10(gain)` so the centerline of a slider sits at
/// 0 dB instead of an arbitrary linear point.
extension SuperequalizerBandsX on SuperequalizerSettings {
  /// 18 band gains, lows-to-highs. Bands the user hasn't touched
  /// read as [kSuperequalizerUnityGain] (the lavfi default), so the
  /// returned list is always exactly [kSuperequalizerBandCount]
  /// long regardless of how sparse the underlying [params] map is.
  List<double> get bands {
    return List.generate(
      kSuperequalizerBandCount,
      (i) => params['${i + 1}b'] ?? kSuperequalizerUnityGain,
      growable: false,
    );
  }

  /// Returns a copy whose [params] reflects [gains]. Bands sitting
  /// at unity are dropped from the map (lavfi treats absent bands as
  /// unity), keeping the serialised filter chain compact. Lists
  /// shorter than [kSuperequalizerBandCount] leave the trailing
  /// bands at unity; longer lists are truncated.
  SuperequalizerSettings withBands(List<double> gains) {
    final next = <String, double>{};
    final n = gains.length < kSuperequalizerBandCount
        ? gains.length
        : kSuperequalizerBandCount;
    for (var i = 0; i < n; i++) {
      final g = gains[i];
      if ((g - kSuperequalizerUnityGain).abs() > 1e-6) {
        next['${i + 1}b'] = g;
      }
    }
    return copyWith(params: next);
  }
}
