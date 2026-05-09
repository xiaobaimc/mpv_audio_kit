import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_dropdown.dart';
import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_lfo_sine.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `flanger`. Like `aphaser` but with
/// a longer base delay producing the classic comb-filtered sweep.
/// Shared LFO sine atom — `speed` is the rate, `depth` the
/// modulation depth (in `[0, 100]`% of base delay).
class FlangerWindow extends StatelessWidget {
  final VoidCallback onClose;
  const FlangerWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).flanger;
        return ProPluginWindow(
          filterName: 'flanger',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

LfoShape _shapeFor(FlangerType t) {
  switch (t) {
    case FlangerType.triangular:
    case FlangerType.t:
      return LfoShape.triangle;
    case FlangerType.sinusoidal:
    case FlangerType.s:
      return LfoShape.sine;
  }
}

String _shapeLabel(FlangerType t) {
  switch (t) {
    case FlangerType.triangular:
    case FlangerType.t:
      return 'triangular';
    case FlangerType.sinusoidal:
    case FlangerType.s:
      return 'sinusoidal';
  }
}

class _Graph extends StatelessWidget {
  final FlangerSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  Widget build(BuildContext context) {
    // Engine `depth` is in [0, 10] — normalise to [0, 1] for the
    // visualizer.
    return Stack(
      children: [
        Positioned.fill(
          child: AtomLfoSine(
            rateHz: settings.speed,
            depth: (settings.depth / 10).clamp(0.0, 1.0),
            shape: _shapeFor(settings.shape),
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
              AtomDropdown<FlangerType>(
                value: settings.shape == FlangerType.t
                    ? FlangerType.triangular
                    : (settings.shape == FlangerType.s
                        ? FlangerType.sinusoidal
                        : settings.shape),
                options: const [
                  FlangerType.triangular,
                  FlangerType.sinusoidal,
                ],
                format: _shapeLabel,
                width: 120,
                onChanged: (v) => player.updateAudioEffects(
                  (b) => b.copyWith(flanger: settings.copyWith(shape: v)),
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
  final FlangerSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(FlangerSettings next) {
    player.updateAudioEffects((b) => b.copyWith(flanger: next));
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
            value: settings.speed,
            min: FlangerSettings.speedMin,
            max: FlangerSettings.speedMax,
            defaultValue: FlangerSettings.speedDefault,
            onChanged: (v) => _apply(settings.copyWith(speed: v)),
            label: 'rate Hz',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.depth,
            min: FlangerSettings.depthMin,
            max: FlangerSettings.depthMax,
            defaultValue: FlangerSettings.depthDefault,
            onChanged: (v) => _apply(settings.copyWith(depth: v)),
            label: 'depth',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.delay,
            min: FlangerSettings.delayMin,
            max: FlangerSettings.delayMax,
            defaultValue: FlangerSettings.delayDefault,
            onChanged: (v) => _apply(settings.copyWith(delay: v)),
            label: 'delay ms',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.regen,
            min: FlangerSettings.regenMin,
            max: FlangerSettings.regenMax,
            defaultValue: FlangerSettings.regenDefault,
            onChanged: (v) => _apply(settings.copyWith(regen: v)),
            label: 'regen',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.width,
            min: FlangerSettings.widthMin,
            max: FlangerSettings.widthMax,
            defaultValue: FlangerSettings.widthDefault,
            onChanged: (v) => _apply(settings.copyWith(width: v)),
            label: 'width',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.phase,
            min: FlangerSettings.phaseMin,
            max: FlangerSettings.phaseMax,
            defaultValue: FlangerSettings.phaseDefault,
            onChanged: (v) => _apply(settings.copyWith(phase: v)),
            label: 'phase',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
        ],
      ),
    );
  }
}
