import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';

/// Stateless text atom — bypasses Flutter's Text/RichText/RenderParagraph
/// chain and paints directly through the Glyph cache. Same call-site
/// ergonomics as Text but goes straight to the dart:ui paragraph layer.
class AtomLabel extends LeafRenderObjectWidget {
  final String text;
  final double fontSize;
  final Color color;
  final bool mono;
  final FontWeight weight;
  final double? letterSpacing;

  const AtomLabel(
    this.text, {
    super.key,
    this.fontSize = ConsoleSkin.sizeBody,
    this.color = ConsoleSkin.fg,
    this.mono = false,
    this.weight = FontWeight.w400,
    this.letterSpacing,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _LabelRender(
        text: text,
        fontSize: fontSize,
        color: color,
        mono: mono,
        weight: weight,
        letterSpacing: letterSpacing,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _LabelRender)
      ..text = text
      ..fontSize = fontSize
      ..color = color
      ..mono = mono
      ..weight = weight
      ..letterSpacing = letterSpacing;
  }
}

class _LabelRender extends RenderBox {
  String _text;
  double _fontSize;
  Color _color;
  bool _mono;
  FontWeight _weight;
  double? _letterSpacing;

  _LabelRender({
    required String text,
    required double fontSize,
    required Color color,
    required bool mono,
    required FontWeight weight,
    required double? letterSpacing,
  })  : _text = text,
        _fontSize = fontSize,
        _color = color,
        _mono = mono,
        _weight = weight,
        _letterSpacing = letterSpacing;

  set text(String v) { if (v != _text) { _text = v; markNeedsLayout(); } }
  set fontSize(double v) { if (v != _fontSize) { _fontSize = v; markNeedsLayout(); } }
  set color(Color v) { if (v != _color) { _color = v; markNeedsPaint(); } }
  set mono(bool v) { if (v != _mono) { _mono = v; markNeedsLayout(); } }
  set weight(FontWeight v) { if (v != _weight) { _weight = v; markNeedsLayout(); } }
  set letterSpacing(double? v) {
    if (v != _letterSpacing) { _letterSpacing = v; markNeedsLayout(); }
  }

  @override
  void performLayout() {
    final measured = Glyph.measure(
      _text,
      size: _fontSize,
      color: _color,
      mono: _mono,
      weight: _weight,
      letterSpacing: _letterSpacing,
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
    );
  }
}
