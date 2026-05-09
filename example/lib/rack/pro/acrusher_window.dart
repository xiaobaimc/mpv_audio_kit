import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `acrusher` (bit-depth + sample-rate
/// destroyer). Hero element is a **stair-stepped sine reference**:
/// a continuous sine wave drawn faintly, with a quantised version
/// stepped by the current `bits` value drawn on top — a literal "this
/// is what your audio looks like after I'm done with it" preview.
///
/// Reference: iZotope Trash 2's bit-crush stage, D16 Decimort,
/// Camel Audio CamelCrusher. All show some flavour of "stepped
/// waveform = lower bit depth", and so does this.
///
/// Knobs: bits, samples (downsampling factor), aa (anti-alias mix),
/// mix (dry/wet), level_in, level_out. The LFO parameters
/// (`lforate`, `lforange`) and `mode` keep their defaults — they're
/// for time-varying destruction patterns rare in music-player use.
class AcrusherWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AcrusherWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.acrusher;
        return ProPluginWindow(
          filterName: 'acrusher',
          onClose: onClose,
          graph: _Graph(settings: s),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

double _ampToDb(double v) =>
    20 * (math.log(v.clamp(1e-9, 64.0)) / math.ln10);

double _dbToAmp(double db) => math.pow(10.0, db / 20.0).toDouble();

class _Graph extends StatelessWidget {
  final AcrusherSettings settings;
  const _Graph({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CrusherPainter(settings: settings),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AtomLabel(
                'bits ${settings.bits.toStringAsFixed(1)}',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                mono: true,
              ),
              AtomLabel(
                '÷${settings.samples.toStringAsFixed(1)}',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                mono: true,
              ),
              AtomLabel(
                'mix ${(settings.mix * 100).toStringAsFixed(0)}%',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                mono: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CrusherPainter extends CustomPainter {
  final AcrusherSettings settings;
  _CrusherPainter({required this.settings});

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);

    // Centerline.
    final mid = plot.top + plot.height / 2;
    PlotChrome.drawHGrid(canvas, size, mid, color: ConsoleSkin.fgFaint);

    // Reference sine — drawn faintly so the user sees the "before".
    final sinePath = Path();
    const cycles = 3;
    final amp = (plot.height / 2) * 0.85;
    for (var x = plot.left; x <= plot.right; x++) {
      final phase = ((x - plot.left) / plot.width) * cycles * 2 * math.pi;
      final y = mid - amp * math.sin(phase);
      if (x == plot.left) {
        sinePath.moveTo(x, y);
      } else {
        sinePath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      sinePath,
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );

    // Quantised + sample-decimated overlay — accent.
    final bits = settings.bits.clamp(1.0, 16.0);
    final levels = math.pow(2, bits) / 2;
    final stride = settings.samples.clamp(1.0, 64.0);
    final crushedPath = Path();
    var lastY = mid;
    for (var x = plot.left; x <= plot.right; x += stride) {
      final phase = ((x - plot.left) / plot.width) * cycles * 2 * math.pi;
      final raw = math.sin(phase);
      final stepped = (raw * levels).round() / levels;
      final y = mid - amp * stepped;
      crushedPath.lineTo(x, lastY);
      crushedPath.lineTo(x, y);
      lastY = y;
    }
    crushedPath.lineTo(plot.right, lastY);
    canvas.drawPath(
      crushedPath,
      Paint()
        ..color = ConsoleSkin.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_CrusherPainter old) => old.settings != settings;
}

class _Controls extends StatelessWidget {
  final AcrusherSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AcrusherSettings next) {
    player.updateAudioEffects((b) => b.copyWith(acrusher: next));
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
            value: settings.bits,
            min: AcrusherSettings.bitsMin,
            // Visual cap at 16 — beyond that, audible difference is
            // imperceptible.
            max: 16,
            defaultValue: 8,
            onChanged: (v) => _apply(settings.copyWith(
              bits: v.clamp(AcrusherSettings.bitsMin, AcrusherSettings.bitsMax),
            )),
            label: 'bits',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.samples,
            min: AcrusherSettings.samplesMin,
            // Visual cap at 32 — heavy aliasing past that.
            max: 32,
            defaultValue: 1,
            onChanged: (v) => _apply(settings.copyWith(
              samples: v.clamp(
                AcrusherSettings.samplesMin,
                AcrusherSettings.samplesMax,
              ),
            )),
            label: 'sample÷',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.aa,
            min: AcrusherSettings.aaMin,
            max: AcrusherSettings.aaMax,
            defaultValue: 0.5,
            onChanged: (v) => _apply(settings.copyWith(aa: v)),
            label: 'anti-alias',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.mix,
            min: AcrusherSettings.mixMin,
            max: AcrusherSettings.mixMax,
            defaultValue: 0.5,
            onChanged: (v) => _apply(settings.copyWith(mix: v)),
            label: 'mix',
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
                AcrusherSettings.level_inMin,
                AcrusherSettings.level_inMax,
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
                AcrusherSettings.level_outMin,
                AcrusherSettings.level_outMax,
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
