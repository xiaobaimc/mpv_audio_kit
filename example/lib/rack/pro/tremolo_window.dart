import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_lfo_sine.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `tremolo` (amplitude modulation).
/// Hero element is an animated LFO sine: rate `f` controls how busy
/// it looks, depth `d` how tall the wave is. Two knobs below.
class TremoloWindow extends StatelessWidget {
  final VoidCallback onClose;
  const TremoloWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).tremolo;
        return ProPluginWindow(
          filterName: 'tremolo',
          onClose: onClose,
          graph: AtomLfoSine(rateHz: s.f, depth: s.d),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final TremoloSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(TremoloSettings next) {
    player.updateAudioEffects((b) => b.copyWith(tremolo: next));
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
            value: settings.f,
            // Spec range goes up to 20 kHz — a knob there is useless
            // (anything past ~30 Hz isn't tremolo, it's ring-mod).
            // Tighten to musical 0.1..30 Hz.
            min: 0.1,
            max: 30,
            defaultValue: 5,
            onChanged: (v) => _apply(settings.copyWith(
              f: v.clamp(TremoloSettings.fMin, TremoloSettings.fMax),
            )),
            label: 'rate Hz',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.d,
            min: TremoloSettings.dMin,
            max: TremoloSettings.dMax,
            defaultValue: TremoloSettings.dDefault,
            onChanged: (v) => _apply(settings.copyWith(d: v)),
            label: 'depth',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
        ],
      ),
    );
  }
}
