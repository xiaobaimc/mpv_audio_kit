import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';
import '../skin/paint_helpers.dart';
import 'command_catalog.dart';
import 'suggestion_engine.dart';

/// Floating list shown above the console prompt while the user is
/// composing a command. Driven by [SuggestionResult] from the engine
/// — the parent owns the keyboard navigation state and just rebuilds
/// the popup with a new [selectedIndex] when arrows are pressed.
///
/// The popup is anchored to the prompt via a [LayerLink] +
/// [CompositedTransformFollower] in the parent's [OverlayEntry]; this
/// widget itself just paints the list.
class SuggestionPopup extends StatelessWidget {
  /// Width and height are fully driven by the host: the popup sits
  /// inside a [Positioned] that bounds it to the console's log area
  /// (below the header, above the prompt). The list shrink-wraps to
  /// content height when smaller than that area, scrolls when taller.
  static const double _rowHeight = 22;

  final List<Suggestion> suggestions;
  final int selectedIndex;
  final String tokenSoFar;
  final ValueChanged<int> onHover;
  final ValueChanged<Suggestion> onTap;

  const SuggestionPopup({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.tokenSoFar,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: ConsoleSkin.bgRaised,
        border: Border.all(
          color: ConsoleSkin.hairline,
          width: ConsoleSkin.hairlinePx,
        ),
        borderRadius: BorderRadius.circular(ConsoleSkin.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemExtent: _rowHeight,
        padding: EdgeInsets.zero,
        itemBuilder: (ctx, i) => _Row(
          suggestion: suggestions[i],
          tokenSoFar: tokenSoFar,
          selected: i == selectedIndex,
          onHover: () => onHover(i),
          onTap: () => onTap(suggestions[i]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Suggestion suggestion;
  final String tokenSoFar;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _Row({
    required this.suggestion,
    required this.tokenSoFar,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clickable = !suggestion.informational;
    return MouseRegion(
      cursor: clickable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: clickable ? (_) => onHover() : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: clickable ? (_) => onTap() : null,
        child: CustomPaint(
          painter: _RowPainter(
            label: suggestion.label,
            tokenSoFar: tokenSoFar,
            hint: suggestion.hint,
            description: suggestion.description,
            kind: suggestion.kind,
            args: suggestion.args,
            activeArgIndex: suggestion.activeArgIndex,
            selected: selected && clickable,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RowPainter extends CustomPainter {
  final String label;
  final String tokenSoFar;
  final String? hint;
  final String? description;
  final SuggestionKind kind;
  final List<CmdArg>? args;
  final int? activeArgIndex;
  final bool selected;

  _RowPainter({
    required this.label,
    required this.tokenSoFar,
    required this.hint,
    required this.description,
    required this.kind,
    required this.args,
    required this.activeArgIndex,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;

    // Background (selected row).
    if (selected) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = ConsoleSkin.accentDim,
      );
    }

    // Kind dot — accent for command, cyan for property, dim for value.
    final dotColor = switch (kind) {
      SuggestionKind.command => ConsoleSkin.accent,
      SuggestionKind.property => ConsoleSkin.meterCyan,
      SuggestionKind.value => ConsoleSkin.fgDim,
    };
    canvas.drawCircle(
      Offset(10, cy),
      2.5,
      Paint()..color = dotColor..isAntiAlias = true,
    );

    // Label — match-prefix bolded by drawing twice (matching segment
    // brighter, rest dim). The kind-coloured label is reserved for
    // the signature helper (Context 4: the row that follows the
    // user through arg-typing). Plain command suggestions in the
    // initial list stay neutral so only the prefix the user has
    // actually typed is tinted accent — colour comes from typing,
    // not just from being a command.
    final inSignature = activeArgIndex != null;
    final labelColor =
        inSignature ? dotColor : ConsoleSkin.fg;
    final labelDim = inSignature
        ? dotColor
        : (selected ? ConsoleSkin.fg : ConsoleSkin.fgDim);
    var x = 22.0;
    // In signature mode the label is the verb the user already typed
    // and won't be editing — no point highlighting the match cursor
    // against it. Without this short-circuit, typing `s` inside an
    // arg of `seek` would re-highlight the `s` in `seek` at a
    // different intensity, which reads as a flicker.
    final lower = label.toLowerCase();
    final tok = tokenSoFar.toLowerCase();
    final matchIdx = inSignature || tok.isEmpty
        ? -1
        : lower.indexOf(tok);
    if (matchIdx < 0) {
      // No highlight — render the whole label at one tone.
      final s = Glyph.measure(
        label,
        size: ConsoleSkin.sizeSmall,
        color: labelColor,
        mono: true,
      );
      Glyph.draw(
        canvas,
        label,
        offset: Offset(x, cy - s.height / 2),
        size: ConsoleSkin.sizeSmall,
        color: labelColor,
        mono: true,
      );
      x += s.width;
    } else {
      // before / match / after rendered separately so the matched
      // segment can be coloured brighter.
      final before = label.substring(0, matchIdx);
      final match = label.substring(matchIdx, matchIdx + tok.length);
      final after = label.substring(matchIdx + tok.length);
      x += _drawSegment(canvas, before, x, cy, labelDim);
      x += _drawSegment(canvas, match, x, cy, ConsoleSkin.accent,
          weight: FontWeight.w700);
      x += _drawSegment(canvas, after, x, cy, labelDim);
    }

    // Args — structured signature when present (commands), dim hint
    // string otherwise (properties / values). For commands the
    // signature renders each arg as its own span so we can paint
    // the active arg in accent — the "you are here" indicator that
    // follows the user across each space they type.
    final argList = args;
    if (argList != null && argList.isNotEmpty) {
      x += 10;
      for (var i = 0; i < argList.length; i++) {
        final a = argList[i];
        final isActive = activeArgIndex == i;
        final isPast =
            activeArgIndex != null && i < activeArgIndex!;
        final color = isActive
            ? ConsoleSkin.accentHot
            : (isPast ? ConsoleSkin.fgFaint : ConsoleSkin.fgDim);
        final span = a.optional ? '[<${a.name}>]' : '<${a.name}>';
        x += _drawSegment(canvas, span, x, cy, color,
            size: ConsoleSkin.sizeTiny,
            weight: isActive ? FontWeight.w700 : FontWeight.w400);
        if (i < argList.length - 1) {
          x += _drawSegment(canvas, ' ', x, cy, ConsoleSkin.fgFaint,
              size: ConsoleSkin.sizeTiny);
        }
      }
    } else {
      final h = hint;
      if (h != null && h.isNotEmpty) {
        x += 10;
        x += _drawSegment(canvas, h, x, cy, ConsoleSkin.fgDim,
            size: ConsoleSkin.sizeTiny);
      }
    }

    // Description — dim right column, ellipsised within remaining
    // width. Right-aligned so it doesn't fight with variable-length
    // labels visually.
    final d = description;
    if (d != null && d.isNotEmpty) {
      final remaining = (size.width - x - 12).clamp(0.0, double.infinity);
      if (remaining > 60) {
        final s = Glyph.measure(
          d,
          size: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgFaint,
          mono: false,
          maxWidth: remaining,
        );
        Glyph.draw(
          canvas,
          d,
          offset: Offset(size.width - s.width - 12, cy - s.height / 2),
          size: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgFaint,
          mono: false,
          maxWidth: remaining,
        );
      }
    }
  }

  double _drawSegment(
    Canvas canvas,
    String text,
    double x,
    double cy,
    Color color, {
    double size = ConsoleSkin.sizeSmall,
    FontWeight weight = FontWeight.w400,
  }) {
    if (text.isEmpty) return 0;
    final s = Glyph.measure(
      text,
      size: size,
      color: color,
      mono: true,
      weight: weight,
    );
    Glyph.draw(
      canvas,
      text,
      offset: Offset(x, cy - s.height / 2),
      size: size,
      color: color,
      mono: true,
      weight: weight,
    );
    return s.width;
  }

  @override
  bool shouldRepaint(_RowPainter old) =>
      old.label != label ||
      old.tokenSoFar != tokenSoFar ||
      old.hint != hint ||
      old.description != description ||
      old.kind != kind ||
      old.activeArgIndex != activeArgIndex ||
      !identical(old.args, args) ||
      old.selected != selected;
}

// ignore: unused_element
void _kindle(Canvas c, Rect r) =>
    box(c, r, fill: ConsoleSkin.bgRaised, border: ConsoleSkin.hairline);
