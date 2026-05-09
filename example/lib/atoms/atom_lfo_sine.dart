import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';

/// Waveform shape rendered by [AtomLfoSine].
enum LfoShape { sine, triangle, square, sawUp, sawDown }

/// Animated LFO visualizer for modulation-family pro windows. Draws a
/// continuous waveform whose period corresponds to [rateHz] (fixed
/// visual scale: 4 Hz spans the panel width) and whose peak-to-peak
/// amplitude scales with [depth] in `[0, 1]`. A travelling marker
/// rides the curve so the user reads the modulation cadence at a
/// glance.
///
/// [shape] selects the waveform: sine, triangle, square, sawUp,
/// sawDown. Default is [LfoShape.sine].
class AtomLfoSine extends StatefulWidget {
  final double rateHz;
  final double depth;
  final LfoShape shape;
  final Color color;

  const AtomLfoSine({
    super.key,
    required this.rateHz,
    required this.depth,
    this.shape = LfoShape.sine,
    this.color = ConsoleSkin.accent,
  });

  @override
  State<AtomLfoSine> createState() => _AtomLfoSineState();
}

class _AtomLfoSineState extends State<AtomLfoSine>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    setState(() => _t = elapsed.inMicroseconds / 1e6);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LfoPainter(
            time: _t,
            rateHz: widget.rateHz,
            depth: widget.depth,
            shape: widget.shape,
            color: widget.color,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _LfoPainter extends CustomPainter {
  final double time;
  final double rateHz;
  final double depth;
  final LfoShape shape;
  final Color color;

  _LfoPainter({
    required this.time,
    required this.rateHz,
    required this.depth,
    required this.shape,
    required this.color,
  });

  // Phase in [0, 1) → normalised waveform value in [-1, 1].
  double _wave(double phase) {
    final p = phase - phase.floorToDouble();
    switch (shape) {
      case LfoShape.sine:
        return math.sin(p * 2 * math.pi);
      case LfoShape.triangle:
        // 0..0.25 → 0..1, 0.25..0.75 → 1..-1, 0.75..1 → -1..0
        if (p < 0.25) return p * 4;
        if (p < 0.75) return 2 - p * 4;
        return p * 4 - 4;
      case LfoShape.square:
        return p < 0.5 ? 1.0 : -1.0;
      case LfoShape.sawUp:
        return p * 2 - 1;
      case LfoShape.sawDown:
        return 1 - p * 2;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid.floorToDouble() + 0.5),
      Offset(size.width, mid.floorToDouble() + 0.5),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );

    // Fixed visual scale: 4 Hz spans the panel width. Drawing rate is
    // independent of the audio engine — the curve just looks busier
    // for fast LFOs and slower for slow ones, which matches user
    // intuition.
    const visibleHz = 4.0;
    final cycles = (rateHz / visibleHz).clamp(0.05, 12.0);
    final amp = (mid - 6) * depth.clamp(0.0, 1.0);
    final timePhase = time * rateHz;

    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..isAntiAlias = true;

    if (shape == LfoShape.square) {
      // Render as horizontal segments + vertical jumps to keep edges
      // crisp instead of diagonal lines from a per-pixel sample.
      final path = Path();
      double? lastY;
      for (var x = 0.0; x <= size.width; x++) {
        final phase = (x / size.width) * cycles - timePhase;
        final y = mid - amp * _wave(phase);
        if (x == 0) {
          path.moveTo(x, y);
        } else if (lastY != null && y != lastY) {
          path.lineTo(x, lastY);
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        lastY = y;
      }
      canvas.drawPath(path, wavePaint);
    } else {
      final path = Path();
      for (var x = 0.0; x <= size.width; x++) {
        final phase = (x / size.width) * cycles - timePhase;
        final y = mid - amp * _wave(phase);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, wavePaint);
    }

    // Travelling phase marker — a vertical hairline at the current
    // sample to make the rate readable on screen.
    final markerPhase = (-time * rateHz) % 1.0;
    final mx =
        (size.width * (markerPhase < 0 ? markerPhase + 1 : markerPhase))
            .floorToDouble() +
            0.5;
    canvas.drawLine(
      Offset(mx, 0),
      Offset(mx, size.height),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 1.4
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_LfoPainter old) =>
      old.time != time ||
      old.rateHz != rateHz ||
      old.depth != depth ||
      old.shape != shape ||
      old.color != color;
}
