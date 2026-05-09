import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';
import '../skin/paint_helpers.dart';

/// Single-purpose interactive atom: hover-aware, press-aware, optional
/// toggle state. Visually flat, single hairline border, no shadow, no
/// ripple, no animation. Hit-padding pads the touch target without
/// inflating the visual size — important on mobile.
class AtomButton extends StatefulWidget {
  final String label;
  final IconGlyph? icon;
  final bool toggled;
  /// For icon buttons whose "on" state is best signalled inside the
  /// glyph itself (e.g. the panel-side filled segment turning accent
  /// when the matching panel is visible) without flipping the whole
  /// button into a toggled box. Independent of [toggled].
  final bool iconActive;
  /// When true, the surrounding box (fill + hairline border) is not
  /// painted — only the icon / label. Hover feedback comes from the
  /// foreground color brightening instead.
  final bool flat;
  /// When true, paint the box as a circle (radius = shortestSide / 2).
  /// Use on icon-only square buttons — transport bar, etc.
  final bool circular;
  final bool enabled;
  final VoidCallback onTap;
  final double? width;
  final double height;
  final EdgeInsets hitPadding;
  final bool mono;

  const AtomButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.toggled = false,
    this.iconActive = false,
    this.flat = false,
    this.circular = false,
    this.enabled = true,
    this.width,
    this.height = ConsoleSkin.row,
    this.hitPadding = const EdgeInsets.all(4),
    this.mono = false,
  });

  @override
  State<AtomButton> createState() => _AtomButtonState();
}

class _AtomButtonState extends State<AtomButton> {
  bool _hover = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _press = false;
      }),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.enabled
            ? (_) => setState(() => _press = true)
            : null,
        onPointerUp: widget.enabled
            ? (_) {
                if (_press) widget.onTap();
                setState(() => _press = false);
              }
            : null,
        onPointerCancel: (_) => setState(() => _press = false),
        child: Padding(
          padding: widget.hitPadding,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _ButtonPainter(
                label: widget.label,
                icon: widget.icon,
                toggled: widget.toggled,
                iconActive: widget.iconActive,
                flat: widget.flat,
                circular: widget.circular,
                enabled: widget.enabled,
                hover: _hover,
                press: _press,
                mono: widget.mono,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  final String label;
  final IconGlyph? icon;
  final bool toggled, iconActive, flat, circular, enabled, hover, press, mono;

  _ButtonPainter({
    required this.label,
    required this.icon,
    required this.toggled,
    required this.iconActive,
    required this.flat,
    required this.circular,
    required this.enabled,
    required this.hover,
    required this.press,
    required this.mono,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fg = !enabled
        ? ConsoleSkin.fgFaint
        : toggled
            ? ConsoleSkin.bg
            : flat
                ? (hover ? ConsoleSkin.fg : ConsoleSkin.fgDim)
                : ConsoleSkin.fg;

    if (!flat) {
      final fill = !enabled
          ? ConsoleSkin.bgRaised
          : toggled
              ? (press ? ConsoleSkin.accentDim : ConsoleSkin.accent)
              : (press ? ConsoleSkin.bgDeep : ConsoleSkin.bgRaised);
      final border = hover && !toggled && enabled
          ? ConsoleSkin.accentDim
          : ConsoleSkin.hairline;
      if (circular) {
        final r = size.shortestSide / 2;
        final c = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(c, r, Paint()..color = fill..isAntiAlias = true);
        canvas.drawCircle(
          c,
          r - ConsoleSkin.hairlinePx / 2,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = ConsoleSkin.hairlinePx
            ..isAntiAlias = true,
        );
      } else {
        box(canvas, rect, fill: fill, border: border);
      }
    }

    final ic = icon;
    if (ic != null) {
      _drawIcon(canvas, size, ic, fg);
    } else {
      final m = Glyph.measure(label,
          size: ConsoleSkin.sizeSmall, color: fg, mono: mono);
      Glyph.draw(canvas, label,
          offset: Offset(
            (size.width  - m.width)  / 2,
            (size.height - m.height) / 2,
          ),
          size: ConsoleSkin.sizeSmall,
          color: fg,
          mono: mono);
    }
  }

  void _drawIcon(Canvas canvas, Size size, IconGlyph ic, Color color) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..isAntiAlias = true;
    final fillPaint = Paint()..color = color..isAntiAlias = true;
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Icon "radius" — half the visible icon footprint. Tuned to land
    // around 40 % of the button diameter at every size from 24 to 48,
    // which is the classic Material / iOS proportion (icon : button =
    // 2 : 5). Smaller than the original 0.28 because circular buttons
    // need more padding around the glyph than rounded-rect buttons did.
    final r  = (size.shortestSide * 0.20).clamp(4.0, 9.0);
    switch (ic) {
      case IconGlyph.play:
        final path = Path()
          ..moveTo(cx - r * 0.7, cy - r)
          ..lineTo(cx + r,        cy)
          ..lineTo(cx - r * 0.7, cy + r)
          ..close();
        canvas.drawPath(path, fillPaint);
        break;
      case IconGlyph.pause:
        final w = r * 0.55;
        canvas.drawRect(Rect.fromLTWH(cx - r * 0.7, cy - r, w, r * 2), fillPaint);
        canvas.drawRect(Rect.fromLTWH(cx + r * 0.15, cy - r, w, r * 2), fillPaint);
        break;
      case IconGlyph.stop:
        canvas.drawRect(Rect.fromLTWH(cx - r * 0.85, cy - r * 0.85, r * 1.7, r * 1.7), fillPaint);
        break;
      case IconGlyph.prev:
        canvas.drawRect(Rect.fromLTWH(cx - r * 0.95, cy - r, 2, r * 2), fillPaint);
        final path = Path()
          ..moveTo(cx + r * 0.6, cy - r)
          ..lineTo(cx - r * 0.4, cy)
          ..lineTo(cx + r * 0.6, cy + r)
          ..close();
        canvas.drawPath(path, fillPaint);
        break;
      case IconGlyph.next:
        canvas.drawRect(Rect.fromLTWH(cx + r * 0.75, cy - r, 2, r * 2), fillPaint);
        final path = Path()
          ..moveTo(cx - r * 0.6, cy - r)
          ..lineTo(cx + r * 0.4, cy)
          ..lineTo(cx - r * 0.6, cy + r)
          ..close();
        canvas.drawPath(path, fillPaint);
        break;
      case IconGlyph.shuffle:
        // Two crossing arrows pointing right — the canonical
        // "swap order" shorthand. Each arrow is a poly-line from the
        // left edge with a short horizontal entry, then a diagonal
        // through the centre, then a short horizontal exit, finished
        // with a filled triangular arrowhead.
        final p1 = Path()
          ..moveTo(cx - r,         cy - r * 0.55)
          ..lineTo(cx - r * 0.30,  cy - r * 0.55)
          ..lineTo(cx + r * 0.45,  cy + r * 0.55)
          ..lineTo(cx + r * 0.80,  cy + r * 0.55);
        canvas.drawPath(p1, paint);
        final p2 = Path()
          ..moveTo(cx - r,         cy + r * 0.55)
          ..lineTo(cx - r * 0.30,  cy + r * 0.55)
          ..lineTo(cx + r * 0.45,  cy - r * 0.55)
          ..lineTo(cx + r * 0.80,  cy - r * 0.55);
        canvas.drawPath(p2, paint);
        // Arrowheads at the right ends. Tip extends past the line end
        // so the stroke and the fill overlap cleanly.
        final ahTop = Path()
          ..moveTo(cx + r * 1.10,  cy - r * 0.55)        // tip
          ..lineTo(cx + r * 0.55,  cy - r * 0.90)        // upper wing
          ..lineTo(cx + r * 0.55,  cy - r * 0.20)        // lower wing
          ..close();
        canvas.drawPath(ahTop, fillPaint);
        final ahBot = Path()
          ..moveTo(cx + r * 1.10,  cy + r * 0.55)
          ..lineTo(cx + r * 0.55,  cy + r * 0.90)
          ..lineTo(cx + r * 0.55,  cy + r * 0.20)
          ..close();
        canvas.drawPath(ahBot, fillPaint);
        break;
      case IconGlyph.loop:
        // Circular arrow — 270° clockwise arc starting at 12 o'clock
        // and ending at 9 o'clock, with a filled triangular arrowhead
        // at the leading edge pointing UP (the tangent direction at
        // the arc's clockwise end). Reads instantly as "this loops".
        final rr = r * 0.78;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: rr),
          -math.pi / 2,                  // start angle: top
          math.pi * 1.5,                 // sweep: 270° clockwise
          false,
          paint,
        );
        // Arrowhead: tip above the arc end, base flush with the end.
        final tipX = cx - rr;
        final ahLoop = Path()
          ..moveTo(tipX,             cy - r * 0.55)      // tip up
          ..lineTo(tipX - r * 0.40,  cy + r * 0.05)      // wing left
          ..lineTo(tipX + r * 0.40,  cy + r * 0.05)      // wing right
          ..close();
        canvas.drawPath(ahLoop, fillPaint);
        break;
      case IconGlyph.panelLeft:
        _drawPanelIcon(canvas, size, color, _PanelSide.left,
            segmentColor: iconActive ? ConsoleSkin.accent : color);
        break;
      case IconGlyph.panelBottom:
        _drawPanelIcon(canvas, size, color, _PanelSide.bottom,
            segmentColor: iconActive ? ConsoleSkin.accent : color);
        break;
      case IconGlyph.panelRight:
        _drawPanelIcon(canvas, size, color, _PanelSide.right,
            segmentColor: iconActive ? ConsoleSkin.accent : color);
        break;
    }
  }

  void _drawPanelIcon(
    Canvas canvas,
    Size size,
    Color color,
    _PanelSide side, {
    required Color segmentColor,
  }) {
    // Icon is sized as a fraction of the button so a square button
    // renders a square icon with uniform margin on every side. The
    // panel-side proportions (segW / segH) stay relative to the
    // icon, not to a hard-coded radius — keeps the segment uniform
    // across button sizes.
    const iconScale = 0.65;
    final w = size.width * iconScale;
    final h = size.height * iconScale;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - w / 2;
    final top = cy - h / 2;
    final outline = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final fill = Paint()..color = segmentColor..isAntiAlias = true;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h),
        const Radius.circular(1.5),
      ),
      outline,
    );
    // Filled segment when iconActive == true; otherwise just the
    // divider line — the panel side is still legible at a glance,
    // but the colour change carries the on/off signal.
    final activeFill = iconActive;
    final divider = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    const cornerR = Radius.circular(1.5);
    // Same proportion on all three sides so the segment thickness
    // looks uniform across the panel-left / -right / -bottom icons.
    const segRatio = 0.30;
    switch (side) {
      case _PanelSide.left:
        final segW = w * segRatio;
        if (activeFill) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(left, top, segW, h),
              topLeft: cornerR,
              bottomLeft: cornerR,
            ),
            fill,
          );
        } else {
          canvas.drawLine(
            Offset(left + segW, top),
            Offset(left + segW, top + h),
            divider,
          );
        }
        break;
      case _PanelSide.right:
        final segW = w * segRatio;
        if (activeFill) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(left + w - segW, top, segW, h),
              topRight: cornerR,
              bottomRight: cornerR,
            ),
            fill,
          );
        } else {
          canvas.drawLine(
            Offset(left + w - segW, top),
            Offset(left + w - segW, top + h),
            divider,
          );
        }
        break;
      case _PanelSide.bottom:
        final segH = h * segRatio;
        if (activeFill) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(left, top + h - segH, w, segH),
              bottomLeft: cornerR,
              bottomRight: cornerR,
            ),
            fill,
          );
        } else {
          canvas.drawLine(
            Offset(left, top + h - segH),
            Offset(left + w, top + h - segH),
            divider,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_ButtonPainter old) =>
      old.label != label ||
      old.icon != icon ||
      old.toggled != toggled ||
      old.iconActive != iconActive ||
      old.flat != flat ||
      old.circular != circular ||
      old.enabled != enabled ||
      old.hover != hover ||
      old.press != press;
}

enum IconGlyph {
  play, pause, stop, prev, next, shuffle, loop,
  panelLeft, panelBottom, panelRight,
}

enum _PanelSide { left, right, bottom }
