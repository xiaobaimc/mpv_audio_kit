import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';

/// Rotary knob — drag-vertical to change value, scroll-wheel to step,
/// double-tap to reset (when [defaultValue] is provided). 270° travel
/// from min (~7 o'clock) to max (~5 o'clock).
class AtomKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double? defaultValue;
  final ValueChanged<double> onChanged;
  final String label;
  final String Function(double) format;
  final double size;
  final bool enabled;

  const AtomKnob({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    required this.format,
    this.defaultValue,
    this.size = 44,
    this.enabled = true,
  });

  @override
  State<AtomKnob> createState() => _AtomKnobState();
}

class _AtomKnobState extends State<AtomKnob> {
  bool _hover = false;
  bool _drag = false;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _delta(double dy) {
    final range = widget.max - widget.min;
    if (range <= 0) return;
    final step = -dy * range / 200;
    final next = (widget.value + step).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged(next);
  }

  void _scroll(double dy) {
    final range = widget.max - widget.min;
    if (range <= 0) return;
    final step = -dy.sign * range / 50;
    final next = (widget.value + step).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged(next);
  }

  void _onTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds < 300) {
      final d = widget.defaultValue;
      if (d != null) widget.onChanged(d);
      _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      _lastTap = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ((widget.value - widget.min) / (widget.max - widget.min))
        .clamp(0.0, 1.0);
    final knobBox = SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _KnobPainter(
          t: t,
          hover: _hover,
          drag: _drag,
          enabled: widget.enabled,
        ),
      ),
    );
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.resizeUpDown
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: widget.enabled
            ? (e) {
                if (e is PointerScrollEvent) _scroll(e.scrollDelta.dy);
              }
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _onTap : null,
          onPanStart: widget.enabled
              ? (_) => setState(() => _drag = true)
              : null,
          onPanUpdate:
              widget.enabled ? (d) => _delta(d.delta.dy) : null,
          onPanEnd:
              widget.enabled ? (_) => setState(() => _drag = false) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              knobBox,
              const SizedBox(height: 2),
              Text(
                widget.format(widget.value),
                style: const TextStyle(
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fg,
                  fontFamily: ConsoleSkin.fontMono,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgDim,
                  fontFamily: ConsoleSkin.fontMono,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double t; // 0..1
  final bool hover;
  final bool drag;
  final bool enabled;

  _KnobPainter({
    required this.t,
    required this.hover,
    required this.drag,
    required this.enabled,
  });

  // 270° travel: starts at 7 o'clock (135°), ends at 5 o'clock (45°),
  // sweeping clockwise through the bottom-right and top arcs.
  static const double _startDeg = 135;
  static const double _sweepDeg = 270;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - 2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background disc.
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = ConsoleSkin.bgRaised,
    );

    // Hairline outline.
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = ConsoleSkin.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = true,
    );

    // Track arc (full 270°).
    final trackPaint = Paint()
      ..color = ConsoleSkin.fgFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      rect.deflate(3),
      _startDeg * math.pi / 180,
      _sweepDeg * math.pi / 180,
      false,
      trackPaint,
    );

    // Filled arc to current value.
    final fillColor = !enabled
        ? ConsoleSkin.fgFaint
        : (drag || hover
            ? ConsoleSkin.accentHot
            : ConsoleSkin.accent);
    canvas.drawArc(
      rect.deflate(3),
      _startDeg * math.pi / 180,
      _sweepDeg * t * math.pi / 180,
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // Indicator: short line from outer edge inward at the value angle.
    final angle = (_startDeg + _sweepDeg * t) * math.pi / 180;
    final outer = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
    final inner = Offset(
      cx + (r - 6) * math.cos(angle),
      cy + (r - 6) * math.sin(angle),
    );
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = enabled ? ConsoleSkin.fg : ConsoleSkin.fgFaint
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.t != t ||
      old.hover != hover ||
      old.drag != drag ||
      old.enabled != enabled;
}

// Shut the analyzer up about an unused import — Glyph stays available
// for cards that want to draw inline labels next to the knob.
// ignore: unused_element
void _kindleGlyph() => Glyph.measure('');
