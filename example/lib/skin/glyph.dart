import 'dart:collection';
import 'dart:ui';

import 'console_skin.dart';

/// TextPainter cache. Painting "0:42" or "THRES" every frame from a
/// CustomPainter without caching would re-run shaping + layout per
/// frame — at 60 fps with 8 meters and a transport bar that's hundreds
/// of layouts a second. Each cache entry holds a laid-out [Paragraph]
/// keyed by (text, style hash). LRU-trimmed at 256 entries.
class Glyph {
  static final LinkedHashMap<int, _Entry> _cache = LinkedHashMap();
  static const int _max = 256;

  /// Layout + paint [text] at [offset]. Returns the entry size so the
  /// caller can advance its layout cursor.
  ///
  /// Pass [maxWidth] to clip overlong strings with an ellipsis (single
  /// line). Pass [wrap] = true to allow multi-line wrapping at
  /// [maxWidth] instead of ellipsizing. Pass [tabular] = true to
  /// enable tabular figures (`tnum`) so digit-substituting readouts
  /// don't reflow horizontally.
  static Size draw(
    Canvas canvas,
    String text, {
    required Offset offset,
    double size = ConsoleSkin.sizeBody,
    Color color = ConsoleSkin.fg,
    bool mono = false,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    TextAlign align = TextAlign.left,
    double? maxWidth,
    bool wrap = false,
    bool tabular = false,
  }) {
    final entry = _entry(text, size, color, mono, weight, letterSpacing, align,
        maxWidth, wrap, tabular);
    canvas.drawParagraph(entry.paragraph, offset);
    return entry.size;
  }

  /// Layout-only — returns the size [text] would occupy with the same
  /// styling. Useful for measuring before placing.
  static Size measure(
    String text, {
    double size = ConsoleSkin.sizeBody,
    Color color = ConsoleSkin.fg,
    bool mono = false,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    TextAlign align = TextAlign.left,
    double? maxWidth,
    bool wrap = false,
    bool tabular = false,
  }) {
    return _entry(text, size, color, mono, weight, letterSpacing, align,
            maxWidth, wrap, tabular)
        .size;
  }

  static _Entry _entry(
    String text,
    double size,
    Color color,
    bool mono,
    FontWeight weight,
    double? letterSpacing,
    TextAlign align,
    double? maxWidth,
    bool wrap,
    bool tabular,
  ) {
    final key = Object.hash(text, size, color, mono, weight, letterSpacing,
        align, maxWidth, wrap, tabular);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    // Three behaviours, picked by the (maxWidth, wrap) pair:
    //   - maxWidth == null            → unlimited width, single line.
    //   - maxWidth set, wrap == false → single line, ellipsized at maxWidth.
    //   - maxWidth set, wrap == true  → wrapped to multiple lines at maxWidth.
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: align,
      fontFamily: mono ? ConsoleSkin.fontMono : ConsoleSkin.fontUI,
      fontSize: size,
      fontWeight: weight,
      maxLines: (maxWidth != null && !wrap) ? 1 : null,
      ellipsis: (maxWidth != null && !wrap) ? '…' : null,
    ))
      ..pushStyle(TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFamily: mono ? ConsoleSkin.fontMono : ConsoleSkin.fontUI,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      ))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: maxWidth ?? double.infinity));
    // When wrapping, `paragraph.width` is the constraint we passed in
    // (the max), not the actual rendered width. `longestLine` gives
    // the bounding box of the laid-out glyphs — that's the size we
    // report so the row doesn't reserve trailing whitespace.
    final entry = _Entry(
      paragraph,
      Size(
        maxWidth == null
            ? paragraph.maxIntrinsicWidth
            : (wrap ? paragraph.longestLine : paragraph.width),
        paragraph.height,
      ),
    );
    _cache[key] = entry;
    if (_cache.length > _max) _cache.remove(_cache.keys.first);
    return entry;
  }
}

class _Entry {
  final Paragraph paragraph;
  final Size size;
  _Entry(this.paragraph, this.size);
}
