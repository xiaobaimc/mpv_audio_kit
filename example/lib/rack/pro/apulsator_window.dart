import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_dropdown.dart';
import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_lfo_sine.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `apulsator` (LFO-based stereo
/// pulsator / amplitude shaper). Hero is the shared LFO atom driven
/// by `hz`. Knobs cover rate (Hz), amount (depth), per-channel
/// offsets, and the input/output levels.
///
/// `bpm` and `ms` are alternative ways to specify the rate; we read
/// `hz` (the canonical) and ignore the others. Switching them via
/// `setAudioEffects` is supported but not surfaced here.
class ApulsatorWindow extends StatelessWidget {
  final VoidCallback onClose;
  const ApulsatorWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).apulsator;
        return ProPluginWindow(
          filterName: 'apulsator',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

LfoShape _shapeFor(ApulsatorMode m) {
  switch (m) {
    case ApulsatorMode.sine:
      return LfoShape.sine;
    case ApulsatorMode.triangle:
      return LfoShape.triangle;
    case ApulsatorMode.square:
      return LfoShape.square;
    case ApulsatorMode.sawup:
      return LfoShape.sawUp;
    case ApulsatorMode.sawdown:
      return LfoShape.sawDown;
  }
}

class _Graph extends StatelessWidget {
  final ApulsatorSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AtomLfoSine(
            rateHz: settings.hz,
            depth: settings.amount,
            shape: _shapeFor(settings.mode),
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
              AtomDropdown<ApulsatorMode>(
                value: settings.mode,
                options: const [
                  ApulsatorMode.sine,
                  ApulsatorMode.triangle,
                  ApulsatorMode.square,
                  ApulsatorMode.sawup,
                  ApulsatorMode.sawdown,
                ],
                format: (m) => m.mpvValue,
                width: 120,
                onChanged: (v) => player.updateAudioEffects(
                  (b) => b.copyWith(apulsator: settings.copyWith(mode: v)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

double _ampToDb(double v) =>
    20 * (math.log(v.clamp(1e-9, 64.0)) / math.ln10);

double _dbToAmp(double db) => math.pow(10.0, db / 20.0).toDouble();

class _Controls extends StatelessWidget {
  final ApulsatorSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(ApulsatorSettings next) {
    player.updateAudioEffects((b) => b.copyWith(apulsator: next));
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
            value: settings.hz,
            // Spec is wide; tighten visual to musical 0.1..30 Hz.
            min: 0.1,
            max: 30,
            defaultValue: 2,
            onChanged: (v) => _apply(settings.copyWith(
              hz: v.clamp(ApulsatorSettings.hzMin, ApulsatorSettings.hzMax),
            )),
            label: 'rate Hz',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.amount,
            min: ApulsatorSettings.amountMin,
            max: ApulsatorSettings.amountMax,
            defaultValue: ApulsatorSettings.amountDefault,
            onChanged: (v) => _apply(settings.copyWith(amount: v)),
            label: 'amount',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.offset_l,
            min: ApulsatorSettings.offset_lMin,
            max: ApulsatorSettings.offset_lMax,
            defaultValue: ApulsatorSettings.offset_lDefault,
            onChanged: (v) => _apply(settings.copyWith(offset_l: v)),
            label: 'offs L',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.offset_r,
            min: ApulsatorSettings.offset_rMin,
            max: ApulsatorSettings.offset_rMax,
            defaultValue: ApulsatorSettings.offset_rDefault,
            onChanged: (v) => _apply(settings.copyWith(offset_r: v)),
            label: 'offs R',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.level_in),
            min: -36,
            max: 36,
            defaultValue: 0,
            onChanged: (db) => _apply(settings.copyWith(
              level_in: _dbToAmp(db).clamp(
                ApulsatorSettings.level_inMin,
                ApulsatorSettings.level_inMax,
              ),
            )),
            label: 'in dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.level_out),
            min: -36,
            max: 36,
            defaultValue: 0,
            onChanged: (db) => _apply(settings.copyWith(
              level_out: _dbToAmp(db).clamp(
                ApulsatorSettings.level_outMin,
                ApulsatorSettings.level_outMax,
              ),
            )),
            label: 'out dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
        ],
      ),
    );
  }
}
