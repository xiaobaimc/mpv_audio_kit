import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/glyph.dart';
import 'atom_label.dart';
import 'atom_text_input.dart';

/// Rotary knob — drag-vertical to change value, scroll-wheel to step,
/// double-click to type a value, Cmd/Ctrl-click to reset (when
/// [defaultValue] is provided). 270° travel from min (~7 o'clock) to
/// max (~5 o'clock).
///
/// **Bipolar mode** ([bipolar] = true): the filled arc grows from the
/// knob's default-position (or 12 o'clock if no default) outward toward
/// the current value, with a small centre tick — matches FabFilter's
/// convention for symmetric params (gain ±, pan, EQ band gain).
///
/// **Numeric entry**: double-click opens a small inline text field
/// over the knob; Enter commits, Esc aborts. The default parser strips
/// trailing units (`Hz / dB / ms / s / %`) and accepts a `k` suffix
/// for thousands. Pass [parse] to override for filter-specific
/// formats (e.g. `1:2` ratios that would otherwise lose precision).
class AtomKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double? defaultValue;
  final ValueChanged<double> onChanged;
  final String label;
  final String Function(double) format;
  /// Optional inverse of [format] for numeric-entry mode. When null,
  /// the default parser is used (handles `1.5k`, `-12 dB`, `200 ms`).
  final double? Function(String)? parse;
  final double size;
  final bool enabled;
  /// Render the fill arc from the default position outward (centre
  /// detent), not from min upward. Use for symmetric parameters where
  /// the centre is the meaningful zero (gain, pan, EQ band gain, …).
  final bool bipolar;

  const AtomKnob({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    required this.format,
    this.parse,
    this.defaultValue,
    this.size = 70,
    this.enabled = true,
    this.bipolar = false,
  });

  @override
  State<AtomKnob> createState() => _AtomKnobState();
}

class _AtomKnobState extends State<AtomKnob> {
  bool _hover = false;
  bool _drag = false;

  /// Floating bubble that appears next to the knob while the user is
  /// dragging or hovering with focus, showing the live formatted value.
  /// Decoupled from [_drag] state so we can also flash it briefly on
  /// scroll-wheel / Cmd-click reset.
  OverlayEntry? _tooltipEntry;
  /// Inline text-input overlay used by numeric-entry mode. Lives in
  /// the root [Overlay] so it can sit above any pro-window chrome.
  OverlayEntry? _entryEntry;
  TextEditingController? _entryController;
  FocusNode? _entryFocus;

  /// Anchor for tooltip / entry positioning — points at the painted
  /// disc, not the column (which includes the value/label text).
  final GlobalKey _discKey = GlobalKey();

  // Drag sensitivity. The divisor maps screen pixels to value range:
  // pixels-per-full-range. Lower = more sensitive (fewer pixels to
  // sweep min→max), higher = more precise (more pixels per unit).
  //
  // Default is 100 px for the full sweep — about a knob-diameter of
  // travel covers the entire range, which feels natural for small
  // knobs. Shift slows it 5× for fine adjustments on narrow ranges
  // (mix, intensity, dry/wet, …). Without Shift, a 5 px drag on a
  // 0..1 range still moves the value by 5%, well above any
  // display-precision threshold.
  static const double _coarseDivisor = 100;
  static const double _fineDivisor = 500;
  static const double _scrollCoarseDivisor = 30;
  static const double _scrollFineDivisor = 150;

  bool get _shift =>
      HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
          k == LogicalKeyboardKey.shiftLeft ||
          k == LogicalKeyboardKey.shiftRight);

  bool get _resetMod =>
      HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
          k == LogicalKeyboardKey.metaLeft ||
          k == LogicalKeyboardKey.metaRight ||
          k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight);

  @override
  void dispose() {
    _hideTooltip();
    _closeEntry();
    super.dispose();
  }

  void _delta(double dy) {
    final range = widget.max - widget.min;
    if (range <= 0) return;
    final step = -dy * range / (_shift ? _fineDivisor : _coarseDivisor);
    final next = (widget.value + step).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged(next);
  }

  void _scroll(double dy) {
    final range = widget.max - widget.min;
    if (range <= 0) return;
    final step = -dy.sign *
        range /
        (_shift ? _scrollFineDivisor : _scrollCoarseDivisor);
    final next = (widget.value + step).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged(next);
  }

  void _reset() {
    final d = widget.defaultValue;
    if (d != null) widget.onChanged(d);
  }

  // ── Tooltip ──────────────────────────────────────────────────────
  //
  // Placed above the disc so it doesn't cover the value/label text
  // below. The tooltip is recomputed on every value change via
  // [_refreshTooltip] (cheap — a single OverlayEntry rebuild).

  void _showTooltip() {
    if (_tooltipEntry != null) return;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;
    _tooltipEntry = OverlayEntry(builder: _buildTooltip);
    overlayState.insert(_tooltipEntry!);
  }

  void _refreshTooltip() => _tooltipEntry?.markNeedsBuild();

  void _hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  Widget _buildTooltip(BuildContext _) {
    final box =
        _discKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return const SizedBox.shrink();
    final discTopLeft = box.localToGlobal(Offset.zero);
    final discCenter = discTopLeft +
        Offset(box.size.width / 2, 0); // top-centre of the disc
    final text = widget.format(widget.value);
    return Positioned(
      // Tooltip is a small floating chip above the disc. Width is
      // unconstrained (shrink-wrap), centred horizontally on the disc.
      left: discCenter.dx - 60,
      top: discCenter.dy - 26,
      width: 120,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ConsoleSkin.bg,
              border: Border.all(
                color: ConsoleSkin.accentDim,
                width: ConsoleSkin.hairlinePx,
              ),
              borderRadius: BorderRadius.circular(ConsoleSkin.radius),
            ),
            child: AtomLabel(
              text,
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.fg,
              mono: true,
            ),
          ),
        ),
      ),
    );
  }

  // ── Numeric entry ───────────────────────────────────────────────

  String _formatForEntry(double v) {
    // The display format includes units / suffixes; for entry we want
    // the bare numeric value so the user types just the number. The
    // default parser will accept either form (with or without unit)
    // so on Enter we round-trip cleanly.
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Default fall-back parser when [widget.parse] is null. Accepts:
  ///   `1500`, `1.5k`, `1500hz`, `-12 db`, `200 ms`, `0.7`, `2:1`.
  static double? _defaultParse(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return null;
    // `2:1` ratio shorthand — divide.
    final colon = s.indexOf(':');
    if (colon > 0) {
      final lhs = double.tryParse(s.substring(0, colon).trim());
      final rhs = double.tryParse(s.substring(colon + 1).trim());
      if (lhs != null && rhs != null && rhs != 0) return lhs / rhs;
    }
    // Strip trailing units; the default formatter may emit any of them.
    s = s.replaceAll(RegExp(r'\s*(hz|db|ms|sec|s|%)\s*$'), '');
    // `k` suffix → multiply by 1000.
    var mult = 1.0;
    if (s.endsWith('k')) {
      mult = 1000;
      s = s.substring(0, s.length - 1);
    }
    final v = double.tryParse(s);
    return v == null ? null : v * mult;
  }

  void _openEntry() {
    if (!widget.enabled) return;
    _hideTooltip();
    if (_entryEntry != null) return;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;
    final box =
        _discKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final discSize = box.size;

    _entryController =
        TextEditingController(text: _formatForEntry(widget.value));
    _entryFocus = FocusNode();
    _entryEntry = OverlayEntry(builder: (_) {
      return Stack(children: [
        // Outside-tap dismisses without committing — same convention
        // as the suggestion popup and the preferences overlay.
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _closeEntry(),
          ),
        ),
        Positioned(
          left: pos.dx,
          top: pos.dy + discSize.height / 2 - 11,
          width: discSize.width,
          height: 22,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                _closeEntry();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: AtomTextInput(
              controller: _entryController!,
              focusNode: _entryFocus!,
              mono: true,
              borderless: false,
              onSubmitted: (_) => _commitEntry(),
            ),
          ),
        ),
      ]);
    });
    overlayState.insert(_entryEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entryFocus == null || _entryController == null) return;
      _entryFocus!.requestFocus();
      _entryController!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _entryController!.text.length,
      );
    });
  }

  void _commitEntry() {
    final text = _entryController?.text ?? '';
    final parsed = widget.parse?.call(text) ?? _defaultParse(text);
    if (parsed != null) {
      widget.onChanged(parsed.clamp(widget.min, widget.max));
    }
    _closeEntry();
  }

  void _closeEntry() {
    _entryEntry?.remove();
    _entryEntry = null;
    _entryController?.dispose();
    _entryController = null;
    _entryFocus?.dispose();
    _entryFocus = null;
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = ((widget.value - widget.min) / (widget.max - widget.min))
        .clamp(0.0, 1.0);
    // Bipolar centre maps the default value into knob-space (or 0.5
    // when the caller hasn't supplied one — defaulting to dead-centre
    // gives the right look for symmetric params with no semantic
    // "default value" of their own).
    final centreT = widget.bipolar
        ? (widget.defaultValue != null
            ? ((widget.defaultValue! - widget.min) /
                    (widget.max - widget.min))
                .clamp(0.0, 1.0)
            : 0.5)
        : 0.0;
    final knobBox = SizedBox(
      key: _discKey,
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _KnobPainter(
          t: t,
          centreT: centreT,
          bipolar: widget.bipolar,
          hover: _hover,
          drag: _drag,
          enabled: widget.enabled,
        ),
      ),
    );
    // Refresh tooltip on every rebuild so the live value tracks the
    // knob during drag without a separate listener.
    if (_tooltipEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTooltip());
    }
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.resizeUpDown
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: widget.enabled
            ? (e) {
                if (e is PointerScrollEvent) _scroll(e.scrollDelta.dy);
              }
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (_) {
                  // Cmd/Ctrl-click resets to default — the FabFilter
                  // gesture. Done in onTapDown so we don't have to
                  // wait for the gesture-arena's onTap delay.
                  if (_resetMod) _reset();
                }
              : null,
          onDoubleTap: widget.enabled ? _openEntry : null,
          onPanStart: widget.enabled
              ? (_) {
                  setState(() => _drag = true);
                  _showTooltip();
                }
              : null,
          onPanUpdate:
              widget.enabled ? (d) => _delta(d.delta.dy) : null,
          onPanEnd: widget.enabled
              ? (_) {
                  setState(() => _drag = false);
                  _hideTooltip();
                }
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              knobBox,
              const SizedBox(height: 2),
              Text(
                widget.format(widget.value),
                style: const TextStyle(
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fg,
                  fontFamily: ConsoleSkin.fontMono,
                  // Tabular figures so the value text doesn't reflow
                  // horizontally as the user drags through digits of
                  // different glyph widths.
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgDim,
                  fontFamily: ConsoleSkin.fontMono,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double t; // 0..1
  final double centreT; // bipolar centre, 0..1 (only used if bipolar)
  final bool bipolar;
  final bool hover;
  final bool drag;
  final bool enabled;

  _KnobPainter({
    required this.t,
    required this.centreT,
    required this.bipolar,
    required this.hover,
    required this.drag,
    required this.enabled,
  });

  // 270° travel: starts at 7 o'clock (135°), ends at 5 o'clock (45°),
  // sweeping clockwise through the bottom-right and top arcs.
  static const double _startDeg = 135;
  static const double _sweepDeg = 270;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - 2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background disc.
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = ConsoleSkin.bgRaised,
    );

    // Hairline outline.
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = ConsoleSkin.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = true,
    );

    // Track arc (full 270°).
    final trackPaint = Paint()
      ..color = ConsoleSkin.fgFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      rect.deflate(3),
      _startDeg * math.pi / 180,
      _sweepDeg * math.pi / 180,
      false,
      trackPaint,
    );

    // Filled arc to current value. Bipolar mode anchors at [centreT]
    // and grows in either direction; unipolar mode grows from 0.
    final fillColor = !enabled
        ? ConsoleSkin.fgFaint
        : (drag || hover
            ? ConsoleSkin.accentHot
            : ConsoleSkin.accent);
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    if (bipolar) {
      final lo = math.min(centreT, t);
      final hi = math.max(centreT, t);
      if (hi > lo) {
        canvas.drawArc(
          rect.deflate(3),
          (_startDeg + _sweepDeg * lo) * math.pi / 180,
          _sweepDeg * (hi - lo) * math.pi / 180,
          false,
          fillPaint,
        );
      }
      // Tick at centre — short radial mark on the OUTSIDE of the
      // track, so it reads as "this is the default" without
      // cluttering the indicator.
      final centreAngle =
          (_startDeg + _sweepDeg * centreT) * math.pi / 180;
      final centreOuter = Offset(
        cx + (r + 1) * math.cos(centreAngle),
        cy + (r + 1) * math.sin(centreAngle),
      );
      final centreInner = Offset(
        cx + (r - 1) * math.cos(centreAngle),
        cy + (r - 1) * math.sin(centreAngle),
      );
      canvas.drawLine(
        centreInner,
        centreOuter,
        Paint()
          ..color = ConsoleSkin.fgDim
          ..strokeWidth = 1
          ..isAntiAlias = true,
      );
    } else {
      canvas.drawArc(
        rect.deflate(3),
        _startDeg * math.pi / 180,
        _sweepDeg * t * math.pi / 180,
        false,
        fillPaint,
      );
    }

    // Indicator: short line from outer edge inward at the value angle.
    final angle = (_startDeg + _sweepDeg * t) * math.pi / 180;
    final outer = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
    final inner = Offset(
      cx + (r - 6) * math.cos(angle),
      cy + (r - 6) * math.sin(angle),
    );
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = enabled ? ConsoleSkin.fg : ConsoleSkin.fgFaint
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.t != t ||
      old.centreT != centreT ||
      old.bipolar != bipolar ||
      old.hover != hover ||
      old.drag != drag ||
      old.enabled != enabled;
}

// Shut the analyzer up about an unused import — Glyph stays available
// for cards that want to draw inline labels next to the knob.
// ignore: unused_element
void _kindleGlyph() => Glyph.measure('');
