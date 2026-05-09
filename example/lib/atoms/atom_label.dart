import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';

/// Stateless text atom — bypasses Flutter's Text/RichText/RenderParagraph
/// chain and paints directly through the Glyph cache. Same call-site
/// ergonomics as Text but goes straight to the dart:ui paragraph layer.
///
/// Default behaviour is single-line at intrinsic width (no wrap, no
/// ellipsis). Pass [wrap] = true to allow multi-line wrapping inside
/// the bounded width of the parent constraints — useful for long
/// descriptions in settings rows / filter pickers.
///
/// Pass [tabular] = true to enable tabular figures (`tnum`) so live
/// readouts like `-12.4 dB` don't reflow horizontally as the digits
/// change between proportional widths. Use for any meter / value
/// label that updates in place.
class AtomLabel extends LeafRenderObjectWidget {
  final String text;
  final double fontSize;
  final Color color;
  final bool mono;
  final FontWeight weight;
  final double? letterSpacing;
  final bool wrap;
  final bool tabular;

  const AtomLabel(
    this.text, {
    super.key,
    this.fontSize = ConsoleSkin.sizeBody,
    this.color = ConsoleSkin.fg,
    this.mono = false,
    this.weight = FontWeight.w400,
    this.letterSpacing,
    this.wrap = false,
    this.tabular = false,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _LabelRender(
        text: text,
        fontSize: fontSize,
        color: color,
        mono: mono,
        weight: weight,
        letterSpacing: letterSpacing,
        wrap: wrap,
        tabular: tabular,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _LabelRender)
      ..text = text
      ..fontSize = fontSize
      ..color = color
      ..mono = mono
      ..weight = weight
      ..letterSpacing = letterSpacing
      ..wrap = wrap
      ..tabular = tabular;
  }
}

class _LabelRender extends RenderBox {
  String _text;
  double _fontSize;
  Color _color;
  bool _mono;
  FontWeight _weight;
  double? _letterSpacing;
  bool _wrap;
  bool _tabular;

  _LabelRender({
    required String text,
    required double fontSize,
    required Color color,
    required bool mono,
    required FontWeight weight,
    required double? letterSpacing,
    required bool wrap,
    required bool tabular,
  })  : _text = text,
        _fontSize = fontSize,
        _color = color,
        _mono = mono,
        _weight = weight,
        _letterSpacing = letterSpacing,
        _wrap = wrap,
        _tabular = tabular;

  set text(String v) { if (v != _text) { _text = v; markNeedsLayout(); } }
  set fontSize(double v) { if (v != _fontSize) { _fontSize = v; markNeedsLayout(); } }
  set color(Color v) { if (v != _color) { _color = v; markNeedsPaint(); } }
  set mono(bool v) { if (v != _mono) { _mono = v; markNeedsLayout(); } }
  set weight(FontWeight v) { if (v != _weight) { _weight = v; markNeedsLayout(); } }
  set letterSpacing(double? v) {
    if (v != _letterSpacing) { _letterSpacing = v; markNeedsLayout(); }
  }
  set wrap(bool v) { if (v != _wrap) { _wrap = v; markNeedsLayout(); } }
  set tabular(bool v) { if (v != _tabular) { _tabular = v; markNeedsLayout(); } }

  /// In wrap mode the layout width comes from the parent's constraints;
  /// outside it the label measures at its intrinsic width.
  double? get _layoutWidth =>
      (_wrap && constraints.maxWidth.isFinite) ? constraints.maxWidth : null;

  @override
  void performLayout() {
    final measured = Glyph.measure(
      _text,
      size: _fontSize,
      color: _color,
      mono: _mono,
      weight: _weight,
      letterSpacing: _letterSpacing,
      maxWidth: _layoutWidth,
      wrap: _wrap,
      tabular: _tabular,
    );
    size = constraints.constrain(measured);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    Glyph.draw(
      context.canvas,
      _text,
      offset: offset,
      size: _fontSize,
      color: _color,
      mono: _mono,
      weight: _weight,
      letterSpacing: _letterSpacing,
      maxWidth: _layoutWidth,
      wrap: _wrap,
      tabular: _tabular,
    );
  }
}
