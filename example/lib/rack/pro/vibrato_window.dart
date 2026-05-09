import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_lfo_sine.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `vibrato` (pitch modulation).
/// Same controls shape as `tremolo` — `f` is the LFO rate, `d` the
/// depth — but the engine modulates pitch instead of amplitude. The
/// LFO visualizer is the same shared atom; the difference is purely
/// what the engine does with it.
class VibratoWindow extends StatelessWidget {
  final VoidCallback onClose;
  const VibratoWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).vibrato;
        return ProPluginWindow(
          filterName: 'vibrato',
          onClose: onClose,
          graph: AtomLfoSine(rateHz: s.f, depth: s.d),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final VibratoSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(VibratoSettings next) {
    player.updateAudioEffects((b) => b.copyWith(vibrato: next));
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
            min: 0.1,
            max: 30,
            defaultValue: 5,
            onChanged: (v) => _apply(settings.copyWith(
              f: v.clamp(VibratoSettings.fMin, VibratoSettings.fMax),
            )),
            label: 'rate Hz',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.d,
            min: VibratoSettings.dMin,
            max: VibratoSettings.dMax,
            defaultValue: VibratoSettings.dDefault,
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
