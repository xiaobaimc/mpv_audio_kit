import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/paint_helpers.dart';

/// Square checkbox-style toggle. 14×14 visual, 24×24 hit target.
/// Filled accent when on, hairline border when off.
class AtomToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const AtomToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<AtomToggle> createState() => _AtomToggleState();
}

class _AtomToggleState extends State<AtomToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.enabled
            ? (_) => widget.onChanged(!widget.value)
            : null,
        // Hit area 24×24, but the painted 14×14 box sits at the
        // BOTTOM-left so its left edge matches every dropdown / number
        // input on the column AND its baseline matches the dropdown's
        // bottom — the description sub-line below sits at the same
        // distance from any control type.
        child: SizedBox(
          width: 24,
          height: 24,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CustomPaint(
                painter: _TogglePainter(
                  value: widget.value,
                  hover: _hover,
                  enabled: widget.enabled,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TogglePainter extends CustomPainter {
  final bool value, hover, enabled;
  _TogglePainter({required this.value, required this.hover, required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fill = !enabled
        ? ConsoleSkin.bgRaised
        : value
            ? ConsoleSkin.accent
            : ConsoleSkin.bgRaised;
    final border = hover && enabled
        ? ConsoleSkin.accentDim
        : ConsoleSkin.hairline;
    box(canvas, rect, fill: fill, border: border);

    if (value) {
      // Small check glyph: two strokes from lower-left to mid, mid to upper-right.
      final paint = Paint()
        ..color = enabled ? ConsoleSkin.bg : ConsoleSkin.fgFaint
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final path = Path()
        ..moveTo(size.width * 0.22, size.height * 0.55)
        ..lineTo(size.width * 0.42, size.height * 0.74)
        ..lineTo(size.width * 0.78, size.height * 0.30);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TogglePainter old) =>
      old.value != value || old.hover != hover || old.enabled != enabled;
}
