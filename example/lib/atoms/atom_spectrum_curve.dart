import 'dart:math' as math;
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
///
/// **Peak-hold:** pass [peakBands] (typically maintained by a
/// [SpectrumPeakHold] buffer) to overlay a slow-falling max-hold
/// outline over the live curve — universal in pro spectrum analyzers.
/// **Tilt:** pass [tiltDbPerOctave] (default 0; recommended 4.5 for
/// music) to tilt the spectrum upward in the highs so signals with
/// natural -4.5 dB/oct slope read as visually flat.
class SpectrumCurve extends StatelessWidget {
  final Float32List bands;
  final Float32List? peakBands;
  final Color color;
  final double tension;
  final bool fillUnder;
  final double fillAlpha;
  final double strokeWidth;
  final double tiltDbPerOctave;
  final double freqMinHz;
  final double freqMaxHz;

  const SpectrumCurve({
    super.key,
    required this.bands,
    this.peakBands,
    this.color = ConsoleSkin.accent,
    this.tension = 1.0,
    this.fillUnder = true,
    this.fillAlpha = 0.30,
    this.strokeWidth = 1.5,
    this.tiltDbPerOctave = 0,
    this.freqMinHz = 20,
    this.freqMaxHz = 20000,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CurvePainter(
          bands: bands,
          peakBands: peakBands,
          color: color,
          tension: tension,
          fillUnder: fillUnder,
          fillAlpha: fillAlpha,
          strokeWidth: strokeWidth,
          tiltDbPerOctave: tiltDbPerOctave,
          freqMinHz: freqMinHz,
          freqMaxHz: freqMaxHz,
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
    Float32List? peakBands,
    Color color = ConsoleSkin.accent,
    double tension = 1.0,
    bool fillUnder = true,
    double fillAlpha = 0.30,
    double strokeWidth = 1.5,
    double tiltDbPerOctave = 0,
    double freqMinHz = 20,
    double freqMaxHz = 20000,
  }) {
    final n = bands.length;
    if (n < 2 || rect.width <= 0 || rect.height <= 0) return;

    // Compute per-band linear gain for the spectrum tilt. With `tilt
    // = 4.5 dB/oct`, a band at 8 kHz (3 oct above 1 kHz) gets a
    // ~+13.5 dB visual boost. The reference is 1 kHz so low and high
    // sides pivot symmetrically. When tilt is 0 the loop short-
    // circuits to 1.0 — no per-band cost.
    List<double>? gains;
    if (tiltDbPerOctave != 0) {
      gains = List<double>.filled(n, 1);
      // Bands are assumed log-spaced from freqMinHz to freqMaxHz.
      final logRatio = math.log(freqMaxHz / freqMinHz);
      for (var i = 0; i < n; i++) {
        final f = freqMinHz * math.exp(logRatio * i / (n - 1));
        final octFromRef = math.log(f / 1000) / math.ln2;
        final dB = tiltDbPerOctave * octFromRef;
        gains[i] = math.pow(10.0, dB / 20).toDouble();
      }
    }

    Offset pt(int i, Float32List src) {
      final clamped = i < 0 ? 0 : (i >= n ? n - 1 : i);
      final x = rect.left + rect.width * clamped / (n - 1);
      var v = src[clamped];
      if (gains != null) v *= gains[clamped];
      v = v.clamp(0.0, 1.0);
      final y = rect.bottom - v * rect.height;
      return Offset(x, y);
    }

    Path buildCurve(Float32List src) {
      final stroke = Path()..moveTo(pt(0, src).dx, pt(0, src).dy);
      final t = tension / 6.0;
      for (var i = 0; i < n - 1; i++) {
        final p0 = pt(i - 1, src);
        final p1 = pt(i, src);
        final p2 = pt(i + 1, src);
        final p3 = pt(i + 2, src);
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
      return stroke;
    }

    final stroke = buildCurve(bands);

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

    // Peak-hold outline drawn ON TOP so it's never hidden by the
    // live fill — matches Voxengo SPAN's convention where the held
    // peaks act as a "ceiling" the live curve dances under.
    if (peakBands != null && peakBands.length == n) {
      final hold = buildCurve(peakBands);
      canvas.drawPath(
        hold,
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
  }
}

/// Per-band peak-hold buffer. Call [update] every time new band data
/// arrives; the buffer keeps the per-band maximum, then bleeds it
/// down at [fallPerSecond] units/s after a [holdMs] ms latch. Pass
/// the buffer's [bands] back to [SpectrumCurve.paintOn] /
/// [SpectrumCurve.peakBands] to render the slow-falling outline.
///
/// Stateful — the caller owns the instance and pumps it on every
/// frame. Lightweight (one Float32List + one Float64List of timings).
class SpectrumPeakHold {
  final int length;
  final double fallPerSecond;
  final int holdMs;
  late final Float32List bands;
  late final Float64List _setAt;
  Duration _last = Duration.zero;

  SpectrumPeakHold({
    required this.length,
    this.fallPerSecond = 0.6,
    this.holdMs = 1500,
  }) {
    bands = Float32List(length);
    _setAt = Float64List(length);
  }

  /// Latch any new peaks; on bands that didn't move up, apply the
  /// slow fall once the hold window elapsed. [now] should be a
  /// monotonic source (e.g. `WidgetsBinding.instance.currentSystemFrameTimeStamp`
  /// or your Ticker's elapsed time).
  void update(Float32List src, Duration now) {
    if (src.length != length) return;
    final dtS = (now - _last).inMicroseconds / 1e6;
    _last = now;
    final nowMs = now.inMilliseconds;
    for (var i = 0; i < length; i++) {
      final v = src[i];
      if (v >= bands[i]) {
        bands[i] = v;
        _setAt[i] = nowMs.toDouble();
      } else {
        if (nowMs - _setAt[i] > holdMs) {
          bands[i] = math.max(v, bands[i] - fallPerSecond * dtS);
        }
      }
    }
  }

  void reset() {
    for (var i = 0; i < length; i++) {
      bands[i] = 0;
      _setAt[i] = 0;
    }
  }
}

class _CurvePainter extends CustomPainter {
  final Float32List bands;
  final Float32List? peakBands;
  final Color color;
  final double tension;
  final bool fillUnder;
  final double fillAlpha;
  final double strokeWidth;
  final double tiltDbPerOctave;
  final double freqMinHz;
  final double freqMaxHz;

  _CurvePainter({
    required this.bands,
    required this.peakBands,
    required this.color,
    required this.tension,
    required this.fillUnder,
    required this.fillAlpha,
    required this.strokeWidth,
    required this.tiltDbPerOctave,
    required this.freqMinHz,
    required this.freqMaxHz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    SpectrumCurve.paintOn(
      canvas,
      Offset.zero & size,
      bands,
      peakBands: peakBands,
      color: color,
      tension: tension,
      fillUnder: fillUnder,
      fillAlpha: fillAlpha,
      strokeWidth: strokeWidth,
      tiltDbPerOctave: tiltDbPerOctave,
      freqMinHz: freqMinHz,
      freqMaxHz: freqMaxHz,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.bands != bands ||
      old.peakBands != peakBands ||
      old.color != color ||
      old.tension != tension ||
      old.fillUnder != fillUnder ||
      old.fillAlpha != fillAlpha ||
      old.strokeWidth != strokeWidth ||
      old.tiltDbPerOctave != tiltDbPerOctave ||
      old.freqMinHz != freqMinHz ||
      old.freqMaxHz != freqMaxHz;
}
