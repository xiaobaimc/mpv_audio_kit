import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';

/// Hand-drawn `×` icon, used as a "close / remove" affordance across
/// the example. Two diagonal strokes inside a fixed-size hit target;
/// the strokes brighten on hover.
///
/// Used by:
/// - `fx_row` to remove a filter from the rack.
/// - `pro_plugin_window`'s header to close the window.
///
/// Hit target stays the same regardless of hover so the cursor doesn't
/// reflow when entering / leaving.
class AtomCloseX extends StatefulWidget {
  final VoidCallback onTap;
  final double width;
  final double height;
  final double radius;
  final EdgeInsets padding;

  const AtomCloseX({
    super.key,
    required this.onTap,
    this.width = 14,
    this.height = 26,
    this.radius = 3.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 6),
  });

  @override
  State<AtomCloseX> createState() => _AtomCloseXState();
}

class _AtomCloseXState extends State<AtomCloseX> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.onTap(),
        child: Padding(
          padding: widget.padding,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _XPainter(hover: _hover, radius: widget.radius),
            ),
          ),
        ),
      ),
    );
  }
}

class _XPainter extends CustomPainter {
  final bool hover;
  final double radius;
  _XPainter({required this.hover, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = hover ? ConsoleSkin.fg : ConsoleSkin.fgDim
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(
        Offset(cx - radius, cy - radius), Offset(cx + radius, cy + radius), paint);
    canvas.drawLine(
        Offset(cx - radius, cy + radius), Offset(cx + radius, cy - radius), paint);
  }

  @override
  bool shouldRepaint(_XPainter old) =>
      old.hover != hover || old.radius != radius;
}
