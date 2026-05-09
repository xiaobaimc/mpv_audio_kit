import 'dart:ui';

import 'console_skin.dart';

/// 1-px hairline with sub-pixel alignment so it stays crisp on all DPRs.
void hairline(
  Canvas canvas,
  Offset a,
  Offset b, {
  Color color = ConsoleSkin.hairline,
  double width = ConsoleSkin.hairlinePx,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  // 0.5 offset on the axis perpendicular to the line keeps a 1 px stroke
  // from blurring across two device pixels.
  if (a.dy == b.dy) {
    final y = a.dy.floorToDouble() + 0.5;
    canvas.drawLine(Offset(a.dx, y), Offset(b.dx, y), paint);
  } else if (a.dx == b.dx) {
    final x = a.dx.floorToDouble() + 0.5;
    canvas.drawLine(Offset(x, a.dy), Offset(x, b.dy), paint);
  } else {
    canvas.drawLine(a, b, paint);
  }
}

/// Filled rect with optional hairline border.
void box(
  Canvas canvas,
  Rect rect, {
  Color fill = ConsoleSkin.bgRaised,
  Color? border,
  double radius = ConsoleSkin.radius,
}) {
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  canvas.drawRRect(rrect, Paint()..color = fill);
  if (border != null) {
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx,
    );
  }
}

/// Short tick mark — used by sliders, knobs, meters.
void tick(
  Canvas canvas,
  Offset at, {
  double length = 4,
  bool vertical = true,
  Color color = ConsoleSkin.fgFaint,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = ConsoleSkin.hairlinePx
    ..isAntiAlias = false;
  if (vertical) {
    canvas.drawLine(at, Offset(at.dx, at.dy + length), paint);
  } else {
    canvas.drawLine(at, Offset(at.dx + length, at.dy), paint);
  }
}
