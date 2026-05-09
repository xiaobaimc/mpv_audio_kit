import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_button.dart';
import '../../atoms/atom_label.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `superequalizer` — the classic
/// **18-band graphic EQ**. Frequencies are fixed (65 Hz → 20 kHz on a
/// roughly half-octave grid); each band has its own vertical slider
/// for gain. The look directly cribs hardware ISO graphic equalizers
/// and Waves Q-Clone-style emulations: a row of slim sliders, with a
/// faint live spectrum behind them so you can see what frequency band
/// you're cutting / boosting.
///
/// `superequalizer` exposes its bands as digit-prefixed parameters
/// `1b`, `2b`, … `18b`, all routed through the bundle's `params`
/// `Map<String, double>` (digit prefixes can't be Dart identifiers).
/// The window reads / writes that map directly, mapping each entry to
/// its frequency band.
class SuperequalizerWindow extends StatelessWidget {
  final VoidCallback onClose;
  const SuperequalizerWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.superequalizer;
        return ProPluginWindow(
          filterName: 'superequalizer',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          // Controls slot is empty — the sliders ARE the controls.
          controls: const SizedBox.shrink(),
        );
      },
    );
  }
}

// 18 bands and unity-gain sourced from the lib-side
// [SuperequalizerBandsX] extension. The half-octave centre
// frequencies are kept stable in [kSuperequalizerFrequencies].
//
// Visual range for the slider strip: linear 0..20 (lavfi spec) but
// drawn in dB so unity sits at the centerline.
const double _gainMin = 0.0;
const double _gainMax = 20.0;

double _gainToDb(double g) =>
    g <= 0 ? -60 : 20 * (math.log(g) / math.ln10);

double _dbToGain(double db) =>
    math.pow(10.0, db / 20.0).toDouble().clamp(_gainMin, _gainMax);

class _Graph extends StatefulWidget {
  final SuperequalizerSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  // Hover state — index of the band currently under the cursor, or
  // null. Drives the band's frequency label highlight + gain readout.
  int? _hoverIdx;

  void _setBand(int idx, double linearGain) {
    final next = [...widget.settings.bands];
    next[idx] = linearGain.clamp(_gainMin, _gainMax);
    widget.player.updateAudioEffects(
      (b) => b.copyWith(superequalizer: widget.settings.withBands(next)),
    );
  }

  void _flat() {
    final next = List<double>.filled(
        kSuperequalizerBandCount, kSuperequalizerUnityGain);
    widget.player.updateAudioEffects(
      (b) => b.copyWith(superequalizer: widget.settings.withBands(next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          // Strip header — FLAT reset on the right.
          SizedBox(
            height: 18,
            child: Row(
              children: [
                const Spacer(),
                AtomButton(
                  label: 'FLAT',
                  mono: true,
                  height: 18,
                  hitPadding: const EdgeInsets.symmetric(horizontal: 6),
                  onTap: _flat,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(builder: (ctx, c) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left dB scale.
                  SizedBox(
                    width: 24,
                    child: _DbScale(),
                  ),
                  const SizedBox(width: 4),
                  // Strip of sliders. One column per band, lows-to-highs.
                  for (var i = 0; i < kSuperequalizerBandCount; i++)
                    Expanded(
                      child: _BandSlider(
                        freqHz: kSuperequalizerFrequencies[i],
                        gain: widget.settings.bands[i],
                        hovered: _hoverIdx == i,
                        onHover: (h) =>
                            setState(() => _hoverIdx = h ? i : null),
                        onChanged: (g) => _setBand(i, g),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatefulWidget {
  final double freqHz;
  final double gain;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.freqHz,
    required this.gain,
    required this.hovered,
    required this.onHover,
    required this.onChanged,
  });

  @override
  State<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends State<_BandSlider> {
  /// Convert a local Y position (0 at top) to a linear gain in
  /// [_gainMin, _gainMax]. Y=0 → max gain; Y=h → 0.
  double _gainFromY(double y, double height) {
    final t = (1 - (y / height).clamp(0.0, 1.0));
    // Use the linear mapping so unity (1.0) sits in the middle of the
    // log-scale dB ruler — UX-wise, dragging the thumb to the
    // centerline gives you back unity, which is what every graphic EQ
    // does.
    final db = _dbMin + t * (_dbMax - _dbMin);
    return _dbToGain(db);
  }

  // dB visual range for the slider — symmetric around 0 dB so a
  // centered thumb means unity.
  static const double _dbMin = -24;
  static const double _dbMax = 24;

  void _handle(Offset local, Size size) {
    widget.onChanged(_gainFromY(local.dy, size.height));
  }

  @override
  Widget build(BuildContext context) {
    final dB = _gainToDb(widget.gain);
    final label = widget.freqHz >= 1000
        ? '${(widget.freqHz / 1000).toStringAsFixed(widget.freqHz < 10000 ? 1 : 0)}k'
        : widget.freqHz.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: MouseRegion(
        onEnter: (_) => widget.onHover(true),
        onExit: (_) => widget.onHover(false),
        cursor: SystemMouseCursors.resizeUpDown,
        child: Column(
          children: [
            // The slider itself.
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  // The slider area is everything except the label
                  // strip at the bottom (16 px). Translate the local
                  // Y into the slider's local coordinate.
                  _handle(d.localPosition, Size(box.size.width, box.size.height - 16));
                },
                onPanUpdate: (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  _handle(d.localPosition, Size(box.size.width, box.size.height - 16));
                },
                onDoubleTap: () => widget.onChanged(kSuperequalizerUnityGain),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SliderPainter(
                      gain: widget.gain,
                      hovered: widget.hovered,
                      dbMin: _dbMin,
                      dbMax: _dbMax,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Frequency label + (when hovered) the current gain in dB.
            SizedBox(
              height: 14,
              child: Center(
                child: AtomLabel(
                  widget.hovered
                      ? '${dB >= 0 ? '+' : ''}${dB.toStringAsFixed(1)}'
                      : label,
                  fontSize: ConsoleSkin.sizeTiny,
                  color: widget.hovered
                      ? ConsoleSkin.fg
                      : ConsoleSkin.fgDim,
                  mono: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  final double gain;
  final bool hovered;
  final double dbMin;
  final double dbMax;
  _SliderPainter({
    required this.gain,
    required this.hovered,
    required this.dbMin,
    required this.dbMax,
  });

  double _yOfDb(double db, Size size) =>
      size.height *
      (1 - ((db - dbMin) / (dbMax - dbMin)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bg);

    // Slider track — thin vertical line through the center.
    final cx = (size.width / 2).floorToDouble() + 0.5;
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height),
      Paint()
        ..color = ConsoleSkin.hairline
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );

    // 0 dB centerline.
    final zeroY = _yOfDb(0, size).floorToDouble() + 0.5;
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );

    // Filled band from 0 dB to current value — accent.
    final db = _gainToDb(gain).clamp(dbMin, dbMax);
    final y = _yOfDb(db, size);
    final fillTop = math.min(y, zeroY);
    final fillBot = math.max(y, zeroY);
    canvas.drawRect(
      Rect.fromLTRB(2, fillTop, size.width - 2, fillBot),
      Paint()
        ..color = ConsoleSkin.accent
            .withValues(alpha: hovered ? 0.55 : 0.40),
    );

    // Thumb — a horizontal accent bar at the current value.
    final thumbColor = hovered ? ConsoleSkin.fg : ConsoleSkin.accent;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 1.5, size.width, 3),
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.gain != gain || old.hovered != hovered;
}

class _DbScale extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DbScalePainter(),
      size: Size.infinite,
    );
  }
}

class _DbScalePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Marks at -24, -12, 0, +12, +24. The "slider area" extends to
    // (size.height - 16) so the labels align with the slider thumb
    // positions; the bottom 16 px is reserved for frequency labels.
    final usable = size.height - 16;
    double yOfDb(double db) =>
        usable * (1 - ((db + 24) / 48).clamp(0.0, 1.0));
    for (final dbInt in [-24, -12, 0, 12, 24]) {
      final y = yOfDb(dbInt.toDouble());
      final paragraph = (TextPainter(
        text: TextSpan(
          text: dbInt > 0 ? '+$dbInt' : '$dbInt',
          style: TextStyle(
            fontFamily: ConsoleSkin.fontMono,
            fontSize: ConsoleSkin.sizeTiny,
            color: dbInt == 0 ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout());
      paragraph.paint(canvas, Offset(0, y - paragraph.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DbScalePainter old) => false;
}
