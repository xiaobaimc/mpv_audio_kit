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
  /// Pass [maxWidth] to clip overlong strings with an ellipsis (single line).
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
  }) {
    final entry = _entry(
        text, size, color, mono, weight, letterSpacing, align, maxWidth);
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
  }) {
    return _entry(
            text, size, color, mono, weight, letterSpacing, align, maxWidth)
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
  ) {
    final key = Object.hash(
        text, size, color, mono, weight, letterSpacing, align, maxWidth);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: align,
      fontFamily: mono ? ConsoleSkin.fontMono : ConsoleSkin.fontUI,
      fontSize: size,
      fontWeight: weight,
      maxLines: maxWidth != null ? 1 : null,
      ellipsis: maxWidth != null ? '…' : null,
    ))
      ..pushStyle(TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFamily: mono ? ConsoleSkin.fontMono : ConsoleSkin.fontUI,
      ))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: maxWidth ?? double.infinity));
    final entry = _Entry(
      paragraph,
      Size(
        maxWidth != null ? paragraph.width : paragraph.maxIntrinsicWidth,
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
