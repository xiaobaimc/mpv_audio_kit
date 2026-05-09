import 'package:flutter/widgets.dart';

import '../atoms/atom_close_x.dart';
import '../atoms/atom_label.dart';
import '../skin/console_skin.dart';
import '../skin/paint_helpers.dart';
import 'pro/pro_registry.dart';

/// Compact filter chip for the FX rack. One small horizontal rectangle
/// per filter in the chain — bypass toggle · name · remove ×. Clicking
/// the chip body opens the filter's dedicated page; clicking the toggle
/// flips the filter's `enabled` flag (live bypass without removing it
/// from the chain); clicking × removes the chip from the rack
/// altogether.
///
/// Chips lay out via [Wrap] in the parent rack — they fill horizontally
/// and the rack's vertical extent grows when the chip row needs more
/// than one line.
class FxChip extends StatefulWidget {
  /// lavfi filter name (`acompressor`, `equalizer`, …).
  final String filterName;
  /// Whether the filter's `enabled` flag is currently true.
  final bool active;
  /// Flips the filter's `enabled` flag without removing it from the
  /// rack — live bypass.
  final ValueChanged<bool> onToggle;
  /// Drops the filter from the rack entirely (also disables it).
  final VoidCallback onRemove;

  const FxChip({
    super.key,
    required this.filterName,
    required this.active,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  State<FxChip> createState() => _FxChipState();
}

class _FxChipState extends State<FxChip> {
  bool _hover = false;

  void _openPage() {
    if (!hasAnyEditor(widget.filterName)) return;
    openProWindow(context, widget.filterName);
  }

  @override
  Widget build(BuildContext context) {
    final hasPage = hasAnyEditor(widget.filterName);
    final border = _hover && hasPage
        ? ConsoleSkin.accentDim
        : ConsoleSkin.hairline;
    final labelColor = widget.active ? ConsoleSkin.fg : ConsoleSkin.fgDim;
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
            // Bypass toggle — the chip's active/inactive switch.
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _BypassToggle(
                value: widget.active,
                onChanged: widget.onToggle,
              ),
            ),
            // Body — clicking it opens the page when one exists.
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: hasPage ? (_) => _openPage() : null,
              child: MouseRegion(
                cursor: hasPage
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
                  child: AtomLabel(
                    widget.filterName,
                    fontSize: ConsoleSkin.sizeSmall,
                    color: labelColor,
                    mono: true,
                  ),
                ),
              ),
            ),
            AtomCloseX(onTap: widget.onRemove),
          ],
        ),
      ),
    );
  }
}

/// Compact bypass toggle scaled for the chip row — 12×12 painted glyph
/// inside a 20×20 hit target. Mirrors [AtomToggle]'s look (filled accent
/// when on, hairline border when off) at chip-friendly proportions.
class _BypassToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _BypassToggle({required this.value, required this.onChanged});

  @override
  State<_BypassToggle> createState() => _BypassToggleState();
}

class _BypassToggleState extends State<_BypassToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.onChanged(!widget.value),
        child: SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CustomPaint(
                painter: _BypassTogglePainter(
                  value: widget.value,
                  hover: _hover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BypassTogglePainter extends CustomPainter {
  final bool value;
  final bool hover;
  _BypassTogglePainter({required this.value, required this.hover});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fill = value ? ConsoleSkin.accent : ConsoleSkin.bgRaised;
    final border = hover ? ConsoleSkin.accentDim : ConsoleSkin.hairline;
    box(canvas, rect, fill: fill, border: border);
    if (value) {
      // Tiny check glyph identical in shape to AtomToggle's, scaled to
      // the smaller box.
      final paint = Paint()
        ..color = ConsoleSkin.bg
        ..strokeWidth = 1.4
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
  bool shouldRepaint(_BypassTogglePainter old) =>
      old.value != value || old.hover != hover;
}
