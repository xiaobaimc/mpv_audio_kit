import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';
import '../skin/paint_helpers.dart';

/// Click-to-open dropdown. Opens an [OverlayEntry] anchored to the
/// button; clicks outside or ESC close it; selecting an option closes
/// and fires [onChanged].
class AtomDropdown<T> extends StatefulWidget {
  final T value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  final String Function(T) format;
  final double width;
  final double height;
  final bool enabled;

  const AtomDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.format,
    this.width = 160,
    this.height = 24,
    this.enabled = true,
  });

  @override
  State<AtomDropdown<T>> createState() => _AtomDropdownState<T>();
}

class _AtomDropdownState<T> extends State<AtomDropdown<T>> {
  final _buttonKey = GlobalKey();
  final _focusNode = FocusNode();
  OverlayEntry? _overlay;
  bool _hover = false;

  @override
  void dispose() {
    // Direct teardown — no setState, the element is already on its way out.
    // Calling setState here would assert against a defunct element.
    _overlay?.remove();
    _overlay = null;
    _focusNode.dispose();
    super.dispose();
  }

  bool get _open => _overlay != null;

  void _toggle() => _open ? _close() : _show();

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  void _show() {
    final btn = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final pos = btn.localToGlobal(Offset.zero);
    final size = btn.size;
    final rowH = 22.0;
    final maxRows = 12;
    final listH = (widget.options.length * rowH).clamp(rowH, rowH * maxRows);

    _overlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Backdrop captures clicks-outside.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            left: pos.dx,
            top: pos.dy + size.height + 2,
            width: size.width,
            child: KeyboardListener(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: (e) {
                if (e is KeyDownEvent &&
                    e.logicalKey == LogicalKeyboardKey.escape) {
                  _close();
                }
              },
              child: _OptionList<T>(
                options: widget.options,
                value: widget.value,
                format: widget.format,
                rowHeight: rowH,
                maxHeight: listH,
                onPick: (v) {
                  _close();
                  widget.onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlay!);
    if (mounted) setState(() {});
  }

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
        onPointerDown: widget.enabled ? (_) => _toggle() : null,
        child: SizedBox(
          key: _buttonKey,
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: _ButtonPainter(
              label: widget.format(widget.value),
              hover: _hover,
              open: _open,
              enabled: widget.enabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  final String label;
  final bool hover, open, enabled;

  _ButtonPainter({
    required this.label,
    required this.hover,
    required this.open,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final border = (open || (hover && enabled))
        ? ConsoleSkin.accentDim
        : ConsoleSkin.hairline;
    box(canvas, rect, fill: ConsoleSkin.bgRaised, border: border);

    final fg = enabled ? ConsoleSkin.fg : ConsoleSkin.fgDim;
    final maxLabelW = size.width - 26;
    final labelSize = Glyph.measure(
      label,
      size: ConsoleSkin.sizeSmall,
      color: fg,
      mono: true,
      maxWidth: maxLabelW,
    );
    Glyph.draw(
      canvas,
      label,
      offset: Offset(8, (size.height - labelSize.height) / 2),
      size: ConsoleSkin.sizeSmall,
      color: fg,
      mono: true,
      maxWidth: maxLabelW,
    );

    // Chevron ▾
    final cx = size.width - 12.0;
    final cy = size.height / 2;
    const cw = 4.0;
    const ch = 3.0;
    final paint = Paint()
      ..color = ConsoleSkin.fgDim
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final path = Path()
      ..moveTo(cx - cw, cy - ch / 2)
      ..lineTo(cx, cy + ch)
      ..lineTo(cx + cw, cy - ch / 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ButtonPainter old) =>
      old.label != label ||
      old.hover != hover ||
      old.open != open ||
      old.enabled != enabled;
}

class _OptionList<T> extends StatelessWidget {
  final List<T> options;
  final T value;
  final String Function(T) format;
  final double rowHeight;
  final double maxHeight;
  final ValueChanged<T> onPick;

  const _OptionList({
    required this.options,
    required this.value,
    required this.format,
    required this.rowHeight,
    required this.maxHeight,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ConsoleSkin.bgRaised,
        border: Border.all(
          color: ConsoleSkin.accentDim,
          width: ConsoleSkin.hairlinePx,
        ),
        borderRadius: BorderRadius.circular(ConsoleSkin.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: options.length,
          itemBuilder: (ctx, i) {
            final opt = options[i];
            final selected = opt == value;
            return _OptionRow(
              label: format(opt),
              selected: selected,
              height: rowHeight,
              onTap: () => onPick(opt),
            );
          },
        ),
      ),
    );
  }
}

class _OptionRow extends StatefulWidget {
  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
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
        child: SizedBox(
          height: widget.height,
          child: CustomPaint(
            painter: _OptionPainter(
              label: widget.label,
              selected: widget.selected,
              hover: _hover,
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionPainter extends CustomPainter {
  final String label;
  final bool selected, hover;

  _OptionPainter({
    required this.label,
    required this.selected,
    required this.hover,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = hover
        ? ConsoleSkin.accentDim
        : (selected ? ConsoleSkin.bgRaised : ConsoleSkin.bgRaised);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final fg = hover ? ConsoleSkin.fg : ConsoleSkin.fg;
    final maxLabelW = size.width - 28;
    final m = Glyph.measure(
      label,
      size: ConsoleSkin.sizeSmall,
      color: fg,
      mono: true,
      maxWidth: maxLabelW,
    );
    Glyph.draw(
      canvas,
      label,
      offset: Offset(8, (size.height - m.height) / 2),
      size: ConsoleSkin.sizeSmall,
      color: fg,
      mono: true,
      maxWidth: maxLabelW,
    );

    if (selected) {
      // Small check on the right
      final cx = size.width - 12.0;
      final cy = size.height / 2;
      const r = 3.5;
      final paint = Paint()
        ..color = ConsoleSkin.accent
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final path = Path()
        ..moveTo(cx - r, cy)
        ..lineTo(cx - r * 0.2, cy + r * 0.8)
        ..lineTo(cx + r, cy - r * 0.8);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_OptionPainter old) =>
      old.label != label || old.selected != selected || old.hover != hover;
}
