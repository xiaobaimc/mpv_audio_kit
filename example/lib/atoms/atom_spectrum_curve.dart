import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';

/// Smooth log-frequency spectrum analyzer (Pro-Q / Voxengo SPAN style).
/// Renders the [bands] envelope as a single Catmull-Rom interpolated
/// curve instead of discrete bars.
///
/// Reusable two ways:
///
///   * As a stand-alone widget — drop-in replacement for an old bar
///     analyzer. The full canvas is the drawing area.
///   * As a static helper — [SpectrumCurve.paintOn] paints into a
///     caller-supplied [Rect] on a caller-supplied [Canvas]. Pro
///     filter editors use this form to overlay the live signal
///     inside their own grid + EQ-response painter without stacking
///     multiple `CustomPaint`s.
class SpectrumCurve extends StatelessWidget {
  final Float32List bands;
  final Color color;
  final double tension;
  final bool fillUnder;
  final double fillAlpha;
  final double strokeWidth;

  const SpectrumCurve({
    super.key,
    required this.bands,
    this.color = ConsoleSkin.accent,
    this.tension = 1.0,
    this.fillUnder = true,
    this.fillAlpha = 0.30,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CurvePainter(
          bands: bands,
          color: color,
          tension: tension,
          fillUnder: fillUnder,
          fillAlpha: fillAlpha,
          strokeWidth: strokeWidth,
        ),
        size: Size.infinite,
      ),
    );
  }

  /// Static painting helper — draws the curve into [rect] on [canvas].
  /// Suitable for embedding in another painter (EQ editor, pro-window
  /// graphs, …) without nesting `CustomPaint` widgets. Y mapping:
  ///   `bands[i] == 0` → `rect.bottom`
  ///   `bands[i] == 1` → `rect.top`
  static void paintOn(
    Canvas canvas,
    Rect rect,
    Float32List bands, {
    Color color = ConsoleSkin.accent,
    double tension = 1.0,
    bool fillUnder = true,
    double fillAlpha = 0.30,
    double strokeWidth = 1.5,
  }) {
    final n = bands.length;
    if (n < 2 || rect.width <= 0 || rect.height <= 0) return;

    Offset pt(int i) {
      final clamped = i < 0 ? 0 : (i >= n ? n - 1 : i);
      final x = rect.left + rect.width * clamped / (n - 1);
      final v = bands[clamped].clamp(0.0, 1.0);
      final y = rect.bottom - v * rect.height;
      return Offset(x, y);
    }

    final stroke = Path()..moveTo(pt(0).dx, pt(0).dy);
    final t = tension / 6.0;
    for (var i = 0; i < n - 1; i++) {
      final p0 = pt(i - 1);
      final p1 = pt(i);
      final p2 = pt(i + 1);
      final p3 = pt(i + 2);
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) * t,
        p1.dy + (p2.dy - p0.dy) * t,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) * t,
        p2.dy - (p3.dy - p1.dy) * t,
      );
      stroke.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    if (fillUnder) {
      final fill = Path.from(stroke)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: fillAlpha),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(rect),
      );
    }

    canvas.drawPath(
      stroke,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }
}

class _CurvePainter extends CustomPainter {
  final Float32List bands;
  final Color color;
  final double tension;
  final bool fillUnder;
  final double fillAlpha;
  final double strokeWidth;

  _CurvePainter({
    required this.bands,
    required this.color,
    required this.tension,
    required this.fillUnder,
    required this.fillAlpha,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    SpectrumCurve.paintOn(
      canvas,
      Offset.zero & size,
      bands,
      color: color,
      tension: tension,
      fillUnder: fillUnder,
      fillAlpha: fillAlpha,
      strokeWidth: strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.bands != bands ||
      old.color != color ||
      old.tension != tension ||
      old.fillUnder != fillUnder ||
      old.fillAlpha != fillAlpha ||
      old.strokeWidth != strokeWidth;
}
