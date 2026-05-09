import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import 'atom_label.dart';
import 'atom_text_input.dart';

/// Numeric text input. Parses on submit, clamps to `[min, max]`,
/// reverts to the previous valid value on parse failure. [decimals]
/// controls the rendered precision (`0` = integer-looking).
///
/// **Drag-to-scrub:** vertical pan on the field changes the value
/// without entering edit mode (Pro Tools / Reaper / FabFilter
/// inspector convention). Single click still enters edit mode. Hold
/// Shift while dragging for 5× finer control. Pass [drag] = false to
/// opt out.
///
/// **Unit suffix:** [unit] is rendered as a small dim label to the
/// right of the input, so the user types just the number and the
/// unit stays visually attached without polluting the parsed text.
class AtomNumberInput extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double? min;
  final double? max;
  final int decimals;
  final double width;
  final bool enabled;
  /// Optional unit label (`Hz`, `dB`, `ms`, `%`, `s`) rendered to the
  /// right of the field. Cosmetic — never part of the parsed value.
  final String? unit;
  /// Enable vertical drag-to-scrub. `false` for inputs that need
  /// pristine text-only behavior (PEM cert paths, file names, …).
  final bool drag;
  /// Pixels of vertical drag that traverse the full `[min, max]`
  /// range. Smaller = more sensitive. Defaults to 200, matching
  /// AtomKnob's coarse divisor.
  final double dragPixelsPerRange;

  const AtomNumberInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.decimals = 0,
    this.width = 80,
    this.enabled = true,
    this.unit,
    this.drag = true,
    this.dragPixelsPerRange = 200,
  });

  @override
  State<AtomNumberInput> createState() => _AtomNumberInputState();
}

class _AtomNumberInputState extends State<AtomNumberInput> {
  late TextEditingController _controller;
  bool _hover = false;

  String _format(double v) => widget.decimals == 0
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(AtomNumberInput old) {
    super.didUpdateWidget(old);
    // External value changed AND we're not currently editing → sync the box.
    if (old.value != widget.value &&
        _controller.text != _format(widget.value)) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _shift =>
      HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
          k == LogicalKeyboardKey.shiftLeft ||
          k == LogicalKeyboardKey.shiftRight);

  void _commit(String raw) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) {
      // Revert to last good value.
      _controller.text = _format(widget.value);
      return;
    }
    var v = parsed;
    if (widget.min != null && v < widget.min!) v = widget.min!;
    if (widget.max != null && v > widget.max!) v = widget.max!;
    _controller.text = _format(v);
    if (v != widget.value) widget.onChanged(v);
  }

  /// Drag-to-scrub: shift dy by `range / dragPixelsPerRange` per
  /// pixel, with Shift = 5× finer. Min / max clamping applied; if
  /// either bound is null the value flows freely in that direction.
  void _scrub(double dy) {
    final lo = widget.min;
    final hi = widget.max;
    // No bounded range → fall back to a flat 1.0 unit per pixel.
    final range = (lo != null && hi != null) ? (hi - lo) : 1.0;
    final divisor =
        _shift ? widget.dragPixelsPerRange * 5 : widget.dragPixelsPerRange;
    final step = -dy * range / divisor;
    var v = widget.value + step;
    if (lo != null && v < lo) v = lo;
    if (hi != null && v > hi) v = hi;
    if (v != widget.value) widget.onChanged(v);
  }

  /// Wheel scroll = step. Same scaling family as drag, just a coarser
  /// divisor so the wheel feels nimble (one notch ≈ 3% of the range,
  /// or 0.6% with Shift).
  void _scroll(double dy) {
    final lo = widget.min;
    final hi = widget.max;
    final range = (lo != null && hi != null) ? (hi - lo) : 1.0;
    final divisor = _shift ? 150.0 : 30.0;
    final step = -dy.sign * range / divisor;
    var v = widget.value + step;
    if (lo != null && v < lo) v = lo;
    if (hi != null && v > hi) v = hi;
    if (v != widget.value) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final input = AtomTextInput(
      controller: _controller,
      onSubmitted: _commit,
      width: widget.width,
      enabled: widget.enabled,
      mono: true,
      align: TextAlign.right,
    );
    // Wrap with a Listener for the scroll wheel and a GestureDetector
    // for vertical drag. The GestureDetector competes with the inner
    // EditableText for the pointer; quick taps reach the input (focus
    // + caret), sustained vertical drags win the arena and scrub.
    final scrubbable = (!widget.enabled || !widget.drag)
        ? input
        : MouseRegion(
            // Resize cursor on hover signals "this number is
            // draggable" — same hint Pro Tools / Reaper use.
            cursor: SystemMouseCursors.resizeUpDown,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) _scroll(e.scrollDelta.dy);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (d) => _scrub(d.delta.dy),
                child: input,
              ),
            ),
          );
    final unit = widget.unit;
    if (unit == null) return scrubbable;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        scrubbable,
        const SizedBox(width: 4),
        AtomLabel(
          unit,
          fontSize: ConsoleSkin.sizeTiny,
          color: _hover ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint,
          mono: true,
        ),
      ],
    );
  }
}
