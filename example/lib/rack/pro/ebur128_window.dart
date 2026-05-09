import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_lufs_meter.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `ebur128` (EBU R128 loudness meter).
/// Read-only dashboard — `ebur128` doesn't normalise the signal, it
/// just measures it, so the window has no audio-shaping knobs. Hero
/// element is the same [AtomLufsMeter] used by `loudnorm`, with the
/// `target` knob below as the only configurable broadcast reference.
///
/// In a future iteration this could be wired to mpv's metadata stream
/// (`ebur128` emits per-frame measurements through metadata) so the
/// numeric readouts become engine-truthful instead of client-side
/// approximated; for now the meter computes its values from the
/// post-filter PCM tap.
class Ebur128Window extends StatelessWidget {
  final VoidCallback onClose;
  const Ebur128Window({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.ebur128;
        return ProPluginWindow(
          filterName: 'ebur128',
          onClose: onClose,
          graph: Column(
            children: [
              Expanded(
                child: AtomLufsMeter(
                  source: p.stream.tap(AudioEffect.ebur128, side: TapSide.post),
                  targetLufs: s.target.toDouble(),
                ),
              ),
              const _MeasureOnlyNote(),
            ],
          ),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

/// Hairline-bordered banner reminding the user that `ebur128` only
/// measures — the `target` knob below is a reference for the readouts,
/// not a normalisation target.
class _MeasureOnlyNote extends StatelessWidget {
  const _MeasureOnlyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: ConsoleSkin.hairline,
          width: ConsoleSkin.hairlinePx,
        ),
      ),
      child: const AtomLabel(
        'Measure-only filter — no signal modification. The target knob '
        'sets a reference for relative readouts only.',
        fontSize: ConsoleSkin.sizeTiny,
        color: ConsoleSkin.fgDim,
        mono: true,
        wrap: true,
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final Ebur128Settings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(Ebur128Settings next) {
    player.updateAudioEffects((b) => b.copyWith(ebur128: next));
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
            value: settings.target.toDouble(),
            min: Ebur128Settings.targetMin.toDouble(),
            max: Ebur128Settings.targetMax.toDouble(),
            defaultValue: Ebur128Settings.targetDefault.toDouble(),
            onChanged: (v) => _apply(settings.copyWith(
              target: v.round().clamp(
                Ebur128Settings.targetMin,
                Ebur128Settings.targetMax,
              ),
            )),
            label: 'target',
            format: (v) => '${v.toStringAsFixed(0)} LUFS',
            size: 70,
          ),
        ],
      ),
    );
  }
}
