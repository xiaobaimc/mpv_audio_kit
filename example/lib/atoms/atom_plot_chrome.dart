import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';

/// Shared "plot chrome" helpers — gutter sizes, tick rendering, and
/// label positioning logic used by every painter that needs axes.
///
/// The pattern (cribbed from FabFilter Pro-Q / Pro-C, iZotope Ozone,
/// TDR Nova, Reaper):
///
/// 1. Reserve gutters at the right (Y labels) and bottom (X labels).
///    The plot rect — where the data / curves are drawn — is inset
///    from the canvas by [rightGutter] and [bottomGutter]. Labels
///    live in those gutters, never inside the plot.
/// 2. Tick marks are short perpendicular lines anchored to the plot
///    edge, pointing inward into the plot. They sit AT the same
///    coordinate as their label, providing the visual anchor.
/// 3. X labels: centered horizontally on the tick, top-aligned a few
///    pixels below the plot's bottom edge.
/// 4. Y labels: right-aligned at the inner edge of the right gutter,
///    vertically centered on the tick. Edge-clamped at the top of
///    the canvas so the highest label (e.g. "0" on a -60..0 scale)
///    doesn't bleed past the plot top.
/// 5. Same font, size, and dim color across every painter so panels
///    look like they came out of the same console.
class PlotChrome {
  /// Pixel margin reserved at the BOTTOM of the canvas for X-axis
  /// labels + tick marks.
  static const double bottomGutter = 16;

  /// Pixel margin reserved at the RIGHT of the canvas for Y-axis
  /// labels + tick marks.
  static const double rightGutter = 32;

  /// Length of a tick mark — short perpendicular line at the plot
  /// edge that visually anchors a label.
  static const double tickLength = 4;

  /// Padding between the tick mark and the label glyph.
  static const double labelGap = 3;

  /// Default label color used when the caller doesn't override.
  static const Color defaultLabelColor = ConsoleSkin.fgDim;

  /// Returns the inner plot rectangle — the area where the data /
  /// curves are drawn. The gutters live OUTSIDE this rect.
  static Rect plotRect(Size canvasSize) => Rect.fromLTWH(
        0,
        0,
        canvasSize.width - rightGutter,
        canvasSize.height - bottomGutter,
      );

  /// Draws an X-axis label + (optional) tick mark. [x] is the
  /// canvas X coordinate where the label is horizontally centered;
  /// it should match the tick's gridline position.
  ///
  /// The tick is drawn OUTSIDE the plot, in the bottom gutter — it
  /// extends the corresponding gridline downward past plot.bottom,
  /// stopping right above the label. The visual effect is a single
  /// continuous line from plot top through the gutter to the label,
  /// removing any ambiguity about which gridline the label belongs
  /// to.
  static void drawXLabel(
    Canvas canvas,
    Size canvasSize,
    double x,
    String text, {
    Color color = defaultLabelColor,
    bool tick = true,
  }) {
    final plot = plotRect(canvasSize);
    if (tick) {
      final tx = x.floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(tx, plot.bottom),
        Offset(tx, plot.bottom + tickLength),
        Paint()
          ..color = color
          ..strokeWidth = ConsoleSkin.hairlinePx
          ..isAntiAlias = false,
      );
    }
    final p = _paragraph(text, color);
    // [Paragraph.width] after layout returns the LAYOUT CONSTRAINT
    // width (here 80), NOT the rendered text width. For centering we
    // want the actual content width — use [longestLine] which gives
    // the bounding box of the rendered glyphs. (Hard-learned: getting
    // this wrong shifts labels by ~30 px and makes them look like
    // they don't belong to their gridline.)
    final w = p.longestLine;
    var dx = x - w / 2;
    // Edge-clamp horizontally so the leftmost / rightmost labels
    // don't bleed past the canvas.
    if (dx < 0) dx = 0;
    if (dx + w > canvasSize.width) dx = canvasSize.width - w;
    canvas.drawParagraph(p, Offset(dx, plot.bottom + tickLength + 1));
  }

  /// Draws a Y-axis label + (optional) tick mark on the RIGHT gutter.
  /// [y] is the canvas Y coordinate where the label is vertically
  /// centered; it should match the tick's gridline position.
  ///
  /// Like [drawXLabel], the tick extends the gridline OUTWARD into
  /// the gutter (rightward past plot.right) so the line ↔ label
  /// connection is visually continuous.
  static void drawYLabelRight(
    Canvas canvas,
    Size canvasSize,
    double y,
    String text, {
    Color color = defaultLabelColor,
    bool tick = true,
  }) {
    final plot = plotRect(canvasSize);
    if (tick) {
      final ty = y.floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(plot.right, ty),
        Offset(plot.right + tickLength, ty),
        Paint()
          ..color = color
          ..strokeWidth = ConsoleSkin.hairlinePx
          ..isAntiAlias = false,
      );
    }
    final p = _paragraph(text, color);
    // Same `longestLine` trick as drawXLabel — `Paragraph.width`
    // returns the layout constraint width, not the rendered text
    // width.
    final w = p.longestLine;
    final innerEdge = plot.right + tickLength + labelGap;
    final outerEdge = canvasSize.width - 2;
    var dx = outerEdge - w;
    if (dx < innerEdge) dx = innerEdge;
    var dy = y - p.height / 2;
    // Edge-clamp vertically so the top-most / bottom-most labels
    // don't bleed past the canvas. (e.g. "0 dB" sitting at plot top
    // would otherwise have its top half clipped above the rect.)
    if (dy < 0) dy = 0;
    if (dy + p.height > canvasSize.height) {
      dy = canvasSize.height - p.height;
    }
    canvas.drawParagraph(p, Offset(dx, dy));
  }

  /// Draws a vertical hairline gridline at [x], from plot top to plot
  /// bottom. Use the variant arguments to flag major / zero lines as
  /// emphasised (brighter colour).
  static void drawVGrid(
    Canvas canvas,
    Size canvasSize,
    double x, {
    Color color = ConsoleSkin.hairline,
  }) {
    final plot = plotRect(canvasSize);
    final tx = x.floorToDouble() + 0.5;
    canvas.drawLine(
      Offset(tx, plot.top),
      Offset(tx, plot.bottom),
      Paint()
        ..color = color
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );
  }

  /// Draws a horizontal hairline gridline at [y], from plot left to
  /// plot right.
  static void drawHGrid(
    Canvas canvas,
    Size canvasSize,
    double y, {
    Color color = ConsoleSkin.hairline,
  }) {
    final plot = plotRect(canvasSize);
    final ty = y.floorToDouble() + 0.5;
    canvas.drawLine(
      Offset(plot.left, ty),
      Offset(plot.right, ty),
      Paint()
        ..color = color
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );
  }

  /// Draws an emphasised "reference line" — slightly brighter colour,
  /// 1.4 px wide. Use for the unity / 0 dB / centre-frequency line on
  /// any plot where the user needs to read "this is the zero". Pro-Q
  /// uses a 1.5 px line in `fgFaint`; same idea here.
  static void drawZeroH(
    Canvas canvas,
    Size canvasSize,
    double y, {
    Color color = ConsoleSkin.fgFaint,
  }) {
    final plot = plotRect(canvasSize);
    final ty = y.floorToDouble() + 0.5;
    canvas.drawLine(
      Offset(plot.left, ty),
      Offset(plot.right, ty),
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..isAntiAlias = true,
    );
  }

  static void drawZeroV(
    Canvas canvas,
    Size canvasSize,
    double x, {
    Color color = ConsoleSkin.fgFaint,
  }) {
    final plot = plotRect(canvasSize);
    final tx = x.floorToDouble() + 0.5;
    canvas.drawLine(
      Offset(tx, plot.top),
      Offset(tx, plot.bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..isAntiAlias = true,
    );
  }

  // ── Log-frequency helpers ──────────────────────────────────────
  //
  // Every audio painter that uses a log-Hz X axis converged on the
  // same constants (50/100/1k/10k as majors, 200/500/2k/5k as minors).
  // Centralised here so a future tweak (e.g. promote 5k to a major
  // by user preference) only happens once.

  /// Major frequency-axis ticks. Positions whose label users actually
  /// hunt for: bass landmark (50/100), mid (1k), treble (10k).
  static const List<double> freqMajor = [50, 100, 1000, 10000];

  /// Minor frequency-axis ticks. Drawn as a dimmer hairline without
  /// labels; helps the eye interpolate between majors.
  static const List<double> freqMinor = [200, 500, 2000, 5000, 20000];

  /// Format a frequency tick as a human label: `50`, `100`, `1k`,
  /// `10k`, `20k`. Centralised so all painters render the same string
  /// for the same Hz value.
  static String formatHz(num hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      // Drop trailing zero on round kilohertz: 1.0k → 1k, 1.5k → 1.5k.
      return k == k.roundToDouble()
          ? '${k.toStringAsFixed(0)}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return hz.toStringAsFixed(0);
  }

  // ── dB-range presets ───────────────────────────────────────────
  //
  // EQ panels typically expose a few canonical Y ranges so the user
  // can zoom in on subtle changes (mastering ±3 / ±6) or zoom out for
  // dramatic curves (±18 / ±30). Pro-Q's range dropdown is the
  // reference. Presets carry their major-tick lists with them so a
  // ±15 dB plot can label every 3 dB while a ±30 plot only labels
  // every 6 dB without the painter having to hand-roll either set.

  static const List<int> dbMajor30 = [-30, -24, -18, -12, -6, 0, 6, 12, 18, 24, 30];
  static const List<int> dbMinor30 = [-27, -21, -15, -9, -3, 3, 9, 15, 21, 27];
  static const List<int> dbMajor18 = [-18, -12, -6, 0, 6, 12, 18];
  static const List<int> dbMinor18 = [-15, -9, -3, 3, 9, 15];
  static const List<int> dbMajor6 = [-6, -3, 0, 3, 6];
  static const List<int> dbMinor6 = [-5, -4, -2, -1, 1, 2, 4, 5];

  static ui.Paragraph _paragraph(String text, Color color) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
    ))
      ..pushStyle(
        ui.TextStyle(color: color, fontSize: ConsoleSkin.sizeTiny),
      )
      ..addText(text);
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: 80));
  }
}
