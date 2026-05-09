import 'package:flutter/widgets.dart';

import 'atom_text_input.dart';

/// Numeric text input. Parses on submit, clamps to [min]..[max], reverts
/// to the previous valid value on parse failure. [decimals] controls the
/// rendered precision (`0` = integer-looking).
class AtomNumberInput extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double? min;
  final double? max;
  final int decimals;
  final double width;
  final bool enabled;

  const AtomNumberInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.decimals = 0,
    this.width = 80,
    this.enabled = true,
  });

  @override
  State<AtomNumberInput> createState() => _AtomNumberInputState();
}

class _AtomNumberInputState extends State<AtomNumberInput> {
  late TextEditingController _controller;

  String _format(double v) =>
      widget.decimals == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(AtomNumberInput old) {
    super.didUpdateWidget(old);
    // External value changed AND we're not currently editing → sync the box.
    if (old.value != widget.value && _controller.text != _format(widget.value)) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return AtomTextInput(
      controller: _controller,
      onSubmitted: _commit,
      width: widget.width,
      enabled: widget.enabled,
      mono: true,
      align: TextAlign.right,
    );
  }
}
