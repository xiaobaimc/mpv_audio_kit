// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// lavfi-side default for `compand.soft-knee` — leaves the
/// transfer-function knee hard.
const double kCompandSoftKneeDefault = 0.01;

/// Typed access over `compand.soft-knee` — the smoothing applied
/// across the breakpoints of the transfer function.
///
/// `soft-knee` is a single numeric AVOption, but the codegen routes
/// it through `params: Map<String, double>` because Dart identifiers
/// can't contain a hyphen. This extension hides that detail so
/// consumers can write `s.withSoftKnee(0.5)` instead of building the
/// map by hand.
extension CompandSoftKneeX on CompandSettings {
  /// Soft-knee smoothing in dB. lavfi default is
  /// [kCompandSoftKneeDefault] — a hard knee.
  double get softKnee => params['soft-knee'] ?? kCompandSoftKneeDefault;

  /// Returns a copy whose `params` map carries [v] under the
  /// `soft-knee` key. Values equal to [kCompandSoftKneeDefault] drop
  /// out of the map (the lavfi default applies implicitly).
  CompandSettings withSoftKnee(double v) {
    final next = Map<String, double>.from(params);
    if ((v - kCompandSoftKneeDefault).abs() < 1e-6) {
      next.remove('soft-knee');
    } else {
      next['soft-knee'] = v;
    }
    return copyWith(params: next);
  }
}
