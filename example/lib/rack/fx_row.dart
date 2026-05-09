import 'package:flutter/widgets.dart';

import '../atoms/atom_label.dart';
import '../skin/console_skin.dart';
import 'pro/pro_registry.dart';

/// Compact filter chip for the FX rack. One small horizontal rectangle
/// per active filter — status dot · name · open-page glyph · remove ×.
/// Click anywhere on the chip body (or on the open-page glyph) to open
/// the filter's dedicated page (the pro window). Click × to remove the
/// filter from the chain. Filters without a registered pro window stay
/// passive: they sit in the chain at default settings, removed via ×.
///
/// Chips lay out via [Wrap] in the parent rack — they fill horizontally
/// and the rack's vertical extent grows when the chip row needs more
/// than one line.
class FxChip extends StatefulWidget {
  /// lavfi filter name (`acompressor`, `equalizer`, …).
  final String filterName;
  /// Removes the filter from the rack chain (sets `enabled = false`
  /// in its slot of the bundle).
  final VoidCallback onRemove;

  const FxChip({
    super.key,
    required this.filterName,
    required this.onRemove,
  });

  @override
  State<FxChip> createState() => _FxChipState();
}

class _FxChipState extends State<FxChip> {
  bool _hover = false;

  void _openPage() {
    if (!proWindowFilters.contains(widget.filterName)) return;
    openProWindow(context, widget.filterName);
  }

  @override
  Widget build(BuildContext context) {
    final hasPage = proWindowFilters.contains(widget.filterName);
    final border = _hover && hasPage
        ? ConsoleSkin.accentDim
        : ConsoleSkin.hairline;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        height: 26,
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        decoration: BoxDecoration(
          color: _hover ? ConsoleSkin.bgRaised : ConsoleSkin.bg,
          border: Border.all(color: border, width: ConsoleSkin.hairlinePx),
          borderRadius: BorderRadius.circular(ConsoleSkin.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Body — clicking it opens the page when one exists.
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: hasPage ? (_) => _openPage() : null,
              child: MouseRegion(
                cursor: hasPage
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _StatusDot(),
                      const SizedBox(width: 8),
                      AtomLabel(
                        widget.filterName,
                        fontSize: ConsoleSkin.sizeSmall,
                        color: ConsoleSkin.fg,
                        mono: true,
                      ),
                      if (hasPage) ...[
                        const SizedBox(width: 6),
                        const _OpenGlyph(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _XButton(onTap: widget.onRemove),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 6,
      height: 6,
      child: CustomPaint(painter: _DotPainter()),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      3,
      Paint()..color = ConsoleSkin.accent..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_DotPainter old) => false;
}

class _OpenGlyph extends StatelessWidget {
  const _OpenGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: CustomPaint(painter: _ArrowPainter()),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 3.5;
    final paint = Paint()
      ..color = ConsoleSkin.fgDim
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
    // ↗ — up-right arrow.
    final p = Path()
      ..moveTo(cx - r, cy + r)
      ..lineTo(cx + r, cy - r)
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy - r)
      ..lineTo(cx + r, cy);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

class _XButton extends StatefulWidget {
  final VoidCallback onTap;
  const _XButton({required this.onTap});

  @override
  State<_XButton> createState() => _XButtonState();
}

class _XButtonState extends State<_XButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            width: 14,
            height: 26,
            child: CustomPaint(painter: _XPainter(hover: _hover)),
          ),
        ),
      ),
    );
  }
}

class _XPainter extends CustomPainter {
  final bool hover;
  _XPainter({required this.hover});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 3.5;
    final paint = Paint()
      ..color = hover ? ConsoleSkin.fg : ConsoleSkin.fgDim
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), paint);
    canvas.drawLine(Offset(cx - r, cy + r), Offset(cx + r, cy - r), paint);
  }

  @override
  bool shouldRepaint(_XPainter old) => old.hover != hover;
}
