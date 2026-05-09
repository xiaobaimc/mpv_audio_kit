import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_lufs_meter.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `loudnorm` (EBU R128 loudness
/// normalisation). Hero element is an [AtomLufsMeter] reading the
/// post-filter PCM tap — three numeric LUFS readouts (momentary,
/// short-term, integrated) plus a true-peak strip and an integrated
/// vertical bar with the configured target marked as a hairline.
///
/// Three knobs for the broadcast spec target: integrated I (LUFS),
/// loudness range LRA (LU), and true-peak ceiling TP (dBTP). The rest
/// of `loudnorm`'s parameters (linear / dual_mono / measured_* /
/// offset / print_format) keep their defaults — they're for offline
/// two-pass workflows and surface negligible value in a real-time
/// editor.
class LoudnormWindow extends StatelessWidget {
  final VoidCallback onClose;
  const LoudnormWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.loudnorm;
        return ProPluginWindow(
          filterName: 'loudnorm',
          onClose: onClose,
          graph: AtomLufsMeter(
            source: p.stream.tap(AudioEffect.loudnorm, side: TapSide.post),
            targetLufs: s.I,
          ),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final LoudnormSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(LoudnormSettings next) {
    player.updateAudioEffects((b) => b.copyWith(loudnorm: next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AtomKnob(
            value: settings.I,
            min: LoudnormSettings.IMin,
            max: LoudnormSettings.IMax,
            defaultValue: LoudnormSettings.IDefault,
            onChanged: (v) => _apply(settings.copyWith(I: v)),
            label: 'integ I',
            format: (v) => '${v.toStringAsFixed(1)} LUFS',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.LRA,
            min: LoudnormSettings.LRAMin,
            max: LoudnormSettings.LRAMax,
            defaultValue: LoudnormSettings.LRADefault,
            onChanged: (v) => _apply(settings.copyWith(LRA: v)),
            label: 'range',
            format: (v) => '${v.toStringAsFixed(1)} LU',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.TP,
            min: LoudnormSettings.TPMin,
            max: LoudnormSettings.TPMax,
            defaultValue: LoudnormSettings.TPDefault,
            onChanged: (v) => _apply(settings.copyWith(TP: v)),
            label: 'tp ceil',
            format: (v) => '${v.toStringAsFixed(1)} dBTP',
            size: 70,
          ),
        ],
      ),
    );
  }
}
