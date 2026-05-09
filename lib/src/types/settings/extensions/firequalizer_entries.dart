// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One break-point of the lavfi `firequalizer` filter's gain curve.
///
/// `firequalizer` interpolates between the declared entries (linearly
/// by default, per its `gain_interpolate(f)` expression) into an
/// arbitrary FIR frequency response. Unlike biquad EQs, the resulting
/// curve can have any shape — the FIR is constructed from these
/// points via inverse-FFT.
final class FirequalizerEntry {
  /// Frequency in Hz.
  final double frequencyHz;

  /// Gain in dB at [frequencyHz].
  final double gainDb;

  const FirequalizerEntry({
    required this.frequencyHz,
    required this.gainDb,
  });

  FirequalizerEntry copyWith({double? frequencyHz, double? gainDb}) =>
      FirequalizerEntry(
        frequencyHz: frequencyHz ?? this.frequencyHz,
        gainDb: gainDb ?? this.gainDb,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FirequalizerEntry &&
          other.frequencyHz == frequencyHz &&
          other.gainDb == gainDb);

  @override
  int get hashCode => Object.hash(frequencyHz, gainDb);

  @override
  String toString() =>
      'FirequalizerEntry(frequency: $frequencyHz Hz, gain: $gainDb dB)';
}

/// Typed access over the `gain_entry` string lavfi's `firequalizer`
/// carries (`entry(freq,gain);entry(freq,gain);…`).
extension FirequalizerEntriesX on FirequalizerSettings {
  /// Decoded gain entries, sorted by ascending frequency.
  List<FirequalizerEntry> get gainEntries {
    if (gain_entry.trim().isEmpty) return const [];
    final out = <FirequalizerEntry>[];
    for (final m in _entryRe.allMatches(gain_entry)) {
      final f = double.tryParse(m.group(1)!);
      final g = double.tryParse(m.group(2)!);
      if (f != null && g != null) {
        out.add(FirequalizerEntry(frequencyHz: f, gainDb: g));
      }
    }
    out.sort((a, b) => a.frequencyHz.compareTo(b.frequencyHz));
    return out;
  }

  /// Returns a copy whose [gain_entry] reflects [entries] (ascending
  /// frequency order). Empty input clears the filter's response.
  FirequalizerSettings withGainEntries(List<FirequalizerEntry> entries) {
    if (entries.isEmpty) return copyWith(gain_entry: '');
    final sorted = [...entries]
      ..sort((a, b) => a.frequencyHz.compareTo(b.frequencyHz));
    return copyWith(
      gain_entry: sorted
          .map((e) =>
              'entry(${e.frequencyHz.toStringAsFixed(1)},${e.gainDb.toStringAsFixed(2)})')
          .join(';'),
    );
  }
}

final RegExp _entryRe =
    RegExp(r'entry\(\s*([-\d.eE+]+)\s*,\s*([-\d.eE+]+)\s*\)');
