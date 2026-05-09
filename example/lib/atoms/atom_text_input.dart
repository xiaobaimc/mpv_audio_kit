import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';

/// Single-line text input. Wraps Flutter's foundation [EditableText]
/// (NOT Material's TextField) so we get cursor / IME / selection /
/// undo for free without dragging in any Material chrome. Box + focus
/// border are painted via our own skin.
class AtomTextInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double width;
  final double height;
  final bool enabled;
  final bool mono;
  final TextAlign align;

  const AtomTextInput({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.width = 120,
    this.height = 24,
    this.enabled = true,
    this.mono = true,
    this.align = TextAlign.left,
  });

  @override
  State<AtomTextInput> createState() => _AtomTextInputState();
}

class _AtomTextInputState extends State<AtomTextInput> {
  late final FocusNode _focusNode;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final border = focused
        ? ConsoleSkin.accent
        : (_hover && widget.enabled
            ? ConsoleSkin.accentDim
            : ConsoleSkin.hairline);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.text
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled
            ? () => _focusNode.requestFocus()
            : null,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.enabled ? ConsoleSkin.bgDeep : ConsoleSkin.bgRaised,
            border: Border.all(color: border, width: ConsoleSkin.hairlinePx),
            borderRadius: BorderRadius.circular(ConsoleSkin.radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          child: EditableText(
            controller: widget.controller,
            focusNode: _focusNode,
            readOnly: !widget.enabled,
            style: TextStyle(
              color: widget.enabled ? ConsoleSkin.fg : ConsoleSkin.fgDim,
              fontSize: ConsoleSkin.sizeSmall,
              fontFamily: widget.mono ? ConsoleSkin.fontMono : ConsoleSkin.fontUI,
            ),
            cursorColor: ConsoleSkin.accent,
            backgroundCursorColor: ConsoleSkin.accentDim,
            selectionColor: ConsoleSkin.accent.withValues(alpha: 0.3),
            maxLines: 1,
            minLines: 1,
            textAlign: widget.align,
            autocorrect: false,
            enableSuggestions: false,
            cursorWidth: 1.2,
            cursorOpacityAnimates: false,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
      ),
    );
  }
}
