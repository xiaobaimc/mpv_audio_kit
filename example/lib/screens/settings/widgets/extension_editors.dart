import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'filter_list_editor.dart';

/// Typed editors for the filters whose lavfi grammar packs structured
/// data into an opaque string parameter. Each editor reads and writes
/// through the `audio_effects_extensions` typed API instead of exposing
/// the raw CSV in a text field.

String _fHz(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);

String _fDb(double v) => '${v.toStringAsFixed(1)}dB';

/// Band editor for `anequalizer`, backed by [AnequalizerBandsX].
///
/// Replaces the raw `params` CSV with one row per [AnequalizerBand]
/// (centre frequency, bandwidth, gain). New bands use the Butterworth
/// shape; the shape of an existing band is preserved across edits.
class AnequalizerBandsEditor extends StatelessWidget {
  final Player player;
  final AnequalizerSettings settings;

  const AnequalizerBandsEditor({
    super.key,
    required this.player,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final bands = settings.bands;
    return FilterListEditor(
      label: 'params · bands',
      columns: const [
        FilterListColumn(label: 'freq', min: 20.0, max: 20000.0, fmt: _fHz),
        FilterListColumn(label: 'width', min: 1.0, max: 10000.0, fmt: _fHz),
        FilterListColumn(label: 'gain', min: -50.0, max: 50.0, fmt: _fDb),
      ],
      rows: [
        for (final b in bands) [b.frequency, b.bandwidth, b.gain],
      ],
      newRow: const [1000.0, 200.0, 0.0],
      onChanged: (rows) {
        final next = <AnequalizerBand>[
          for (var i = 0; i < rows.length; i++)
            AnequalizerBand(
              frequency: rows[i][0],
              bandwidth: rows[i][1],
              gain: rows[i][2],
              type: i < bands.length
                  ? bands[i].type
                  : AnequalizerBandType.butterworth,
            ),
        ];
        player.updateAudioEffects(
          (e) => e.copyWith(anequalizer: settings.withBands(next)),
        );
      },
    );
  }
}
