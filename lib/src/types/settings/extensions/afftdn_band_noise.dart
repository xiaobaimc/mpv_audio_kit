// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// Number of fixed bands lavfi's `afftdn` uses for its custom noise
/// profile — the filter splits the spectrum into 15 logarithmic bands
/// and lets the consumer set a noise floor per band.
const int kAfftdnBandCount = 15;

/// Default per-band noise floor when none is provided.
const double kAfftdnBandNoiseDefault = 0.0;

/// Typed access over the `band_noise` (alias `bn`) string lavfi's
/// `afftdn` packs as space- or pipe-separated noise levels per band.
///
/// The list is always exactly [kAfftdnBandCount] long; entries the
/// consumer doesn't touch read as [kAfftdnBandNoiseDefault].
extension AfftdnBandNoiseX on AfftdnSettings {
  /// Decoded per-band noise floors, lows-to-highs, in lavfi's
  /// 15-band logarithmic split. Always length [kAfftdnBandCount];
  /// missing entries fill with [kAfftdnBandNoiseDefault].
  List<double> get bandNoiseLevels {
    final raw = band_noise.trim();
    final parsed = <double>[];
    if (raw.isNotEmpty) {
      for (final part in raw.split(RegExp(r'[ |]+'))) {
        final v = double.tryParse(part.trim());
        if (v != null) parsed.add(v);
        if (parsed.length >= kAfftdnBandCount) break;
      }
    }
    while (parsed.length < kAfftdnBandCount) {
      parsed.add(kAfftdnBandNoiseDefault);
    }
    return List.unmodifiable(parsed);
  }

  /// Returns a copy whose [band_noise] reflects [levels]. Lists
  /// shorter than [kAfftdnBandCount] pad with
  /// [kAfftdnBandNoiseDefault]; longer lists are truncated. The
  /// emitted CSV uses pipe separation (lavfi accepts both space and
  /// pipe; pipe is unambiguous in mpv's filter-args parser).
  AfftdnSettings withBandNoiseLevels(List<double> levels) {
    final padded = List<double>.filled(kAfftdnBandCount, kAfftdnBandNoiseDefault);
    for (var i = 0; i < kAfftdnBandCount && i < levels.length; i++) {
      padded[i] = levels[i];
    }
    return copyWith(
      band_noise:
          padded.map((v) => v.toStringAsFixed(2)).join('|'),
    );
  }
}
