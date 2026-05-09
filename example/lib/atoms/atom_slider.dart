import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';

/// Horizontal value slider. No thumb (Reaper-style: filled portion =
/// value), 2 px track, hover hairline highlight, drag updates value
/// during the gesture.
class AtomSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final double height;
  final String? leftLabel;
  final String? rightLabel;

  const AtomSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
    this.height = 18,
    this.leftLabel,
    this.rightLabel,
  });

  @override
  State<AtomSlider> createState() => _AtomSliderState();
}

class _AtomSliderState extends State<AtomSlider> {
  bool _hover = false;
  bool _drag = false;

  void _emit(double localX, double width) {
    if (!widget.enabled || width <= 0) return;
    final t = (localX / width).clamp(0.0, 1.0);
    widget.onChanged(widget.min + (widget.max - widget.min) * t);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _drag = false;
      }),
      child: LayoutBuilder(
        builder: (ctx, c) {
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              setState(() => _drag = true);
              _emit(e.localPosition.dx, c.maxWidth);
            },
            onPointerMove: (e) {
              if (_drag) _emit(e.localPosition.dx, c.maxWidth);
            },
            onPointerUp: (_) => setState(() => _drag = false),
            onPointerCancel: (_) => setState(() => _drag = false),
            child: SizedBox(
              height: widget.height,
              child: CustomPaint(
                painter: _SliderPainter(
                  t: ((widget.value - widget.min) / (widget.max - widget.min))
                      .clamp(0.0, 1.0),
                  hover: _hover,
                  enabled: widget.enabled,
                  leftLabel: widget.leftLabel,
                  rightLabel: widget.rightLabel,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  final double t;
  final bool hover, enabled;
  final String? leftLabel, rightLabel;

  _SliderPainter({
    required this.t,
    required this.hover,
    required this.enabled,
    required this.leftLabel,
    required this.rightLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final trackY = cy - 1;
    final trackH = 2.0;

    final base = enabled ? ConsoleSkin.fgFaint : ConsoleSkin.hairline;
    final fill = !enabled
        ? ConsoleSkin.fgFaint
        : (hover ? ConsoleSkin.accentHot : ConsoleSkin.accent);

    canvas.drawRect(Rect.fromLTWH(0, trackY, size.width, trackH),
        Paint()..color = base);
    canvas.drawRect(Rect.fromLTWH(0, trackY, size.width * t, trackH),
        Paint()..color = fill);

    if (leftLabel != null) {
      Glyph.draw(canvas, leftLabel!,
          offset: Offset(0, 0),
          size: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgDim,
          mono: true);
    }
    if (rightLabel != null) {
      final m = Glyph.measure(rightLabel!,
          size: ConsoleSkin.sizeTiny, color: ConsoleSkin.fgDim, mono: true);
      Glyph.draw(canvas, rightLabel!,
          offset: Offset(size.width - m.width, 0),
          size: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgDim,
          mono: true);
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.t != t ||
      old.hover != hover ||
      old.enabled != enabled ||
      old.leftLabel != leftLabel ||
      old.rightLabel != rightLabel;
}
