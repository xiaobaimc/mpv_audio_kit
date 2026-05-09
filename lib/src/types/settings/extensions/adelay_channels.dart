// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// Typed access over lavfi's `adelay.delays` — a pipe-separated list
/// of per-channel delays. The Nth entry is the delay applied to the
/// Nth output channel.
///
/// The lavfi grammar accepts a unit suffix (`ms` for milliseconds,
/// `s` for seconds, `S` for samples). The typed view here normalises
/// to **milliseconds**: any suffix is stripped on parse, and the
/// emitter always writes plain milliseconds. Consumers that need
/// sample-accurate delay should write the raw string via
/// [AdelaySettings.copyWith] instead.
extension AdelayChannelsX on AdelaySettings {
  /// Decoded list of channel delays in milliseconds, in declaration
  /// order (channel 0 first).
  List<double> get channelDelaysMs {
    if (delays.trim().isEmpty) return const [];
    final out = <double>[];
    for (final part in delays.split('|')) {
      final stripped = part.trim().replaceAll(RegExp(r'[a-zA-Z]'), '');
      final v = double.tryParse(stripped);
      if (v != null) out.add(v);
    }
    return out;
  }

  /// Returns a copy whose [delays] string reflects [delaysMs] in
  /// declaration order. Empty input clears the filter.
  AdelaySettings withChannelDelaysMs(List<double> delaysMs) {
    if (delaysMs.isEmpty) return copyWith(delays: '');
    return copyWith(
      delays:
          delaysMs.map((d) => '${d.toStringAsFixed(2)}ms').join('|'),
    );
  }
}
