import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_dropdown.dart';
import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_lfo_sine.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `aphaser`. Hero is the shared LFO
/// sine — `speed` is the rate, `decay` is depth — and the four knobs
/// below cover gain in/out, delay (the all-pass stages' base delay),
/// and decay (LFO depth in the engine).
class AphaserWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AphaserWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).aphaser;
        return ProPluginWindow(
          filterName: 'aphaser',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

LfoShape _shapeFor(AphaserType t) {
  switch (t) {
    case AphaserType.triangular:
    case AphaserType.t:
      return LfoShape.triangle;
    case AphaserType.sinusoidal:
    case AphaserType.s:
      return LfoShape.sine;
  }
}

String _shapeLabel(AphaserType t) {
  switch (t) {
    case AphaserType.triangular:
    case AphaserType.t:
      return 'triangular';
    case AphaserType.sinusoidal:
    case AphaserType.s:
      return 'sinusoidal';
  }
}

class _Graph extends StatelessWidget {
  final AphaserSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AtomLfoSine(
            rateHz: settings.speed,
            depth: settings.decay,
            shape: _shapeFor(settings.type),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AtomLabel(
                'shape',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                mono: true,
              ),
              const SizedBox(width: 6),
              AtomDropdown<AphaserType>(
                value: settings.type == AphaserType.t
                    ? AphaserType.triangular
                    : (settings.type == AphaserType.s
                        ? AphaserType.sinusoidal
                        : settings.type),
                options: const [
                  AphaserType.triangular,
                  AphaserType.sinusoidal,
                ],
                format: _shapeLabel,
                width: 120,
                onChanged: (v) => player.updateAudioEffects(
                  (b) => b.copyWith(aphaser: settings.copyWith(type: v)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final AphaserSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AphaserSettings next) {
    player.updateAudioEffects((b) => b.copyWith(aphaser: next));
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
            // parse.py reports inverted/missing speed bounds for
            // aphaser; use the musical phaser range (0.1..5 Hz).
            value: settings.speed,
            min: 0.1,
            max: 5,
            defaultValue: AphaserSettings.speedDefault,
            onChanged: (v) => _apply(settings.copyWith(speed: v)),
            label: 'rate Hz',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            // parse.py reports decayMax = missing; lavfi accepts up
            // to 0.99. Fall back to that range.
            value: settings.decay,
            min: AphaserSettings.decayMin,
            max: 0.99,
            defaultValue: AphaserSettings.decayDefault,
            onChanged: (v) => _apply(settings.copyWith(decay: v)),
            label: 'decay',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.delay,
            min: AphaserSettings.delayMin,
            max: AphaserSettings.delayMax,
            defaultValue: AphaserSettings.delayDefault,
            onChanged: (v) => _apply(settings.copyWith(delay: v)),
            label: 'delay ms',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.in_gain,
            min: AphaserSettings.in_gainMin,
            max: AphaserSettings.in_gainMax,
            defaultValue: AphaserSettings.in_gainDefault,
            onChanged: (v) => _apply(settings.copyWith(in_gain: v)),
            label: 'in gain',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.out_gain,
            min: AphaserSettings.out_gainMin,
            max: AphaserSettings.out_gainMax,
            defaultValue: AphaserSettings.out_gainDefault,
            onChanged: (v) => _apply(settings.copyWith(out_gain: v)),
            label: 'out gain',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
        ],
      ),
    );
  }
}
