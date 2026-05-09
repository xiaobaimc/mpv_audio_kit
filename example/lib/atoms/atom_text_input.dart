import 'package:flutter/services.dart';
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
  /// Width in logical pixels. When `null`, the input fills its
  /// parent's horizontal constraint (use inside an [Expanded] /
  /// [SizedBox] / [Flex]).
  final double? width;
  final double height;
  final bool enabled;
  final bool mono;
  final TextAlign align;
  /// Optional external focus node — useful when the parent needs to
  /// intercept key events (e.g. terminal-style command-history
  /// navigation) via a wrapping [Focus]. When `null`, the widget
  /// owns and disposes its own focus node.
  final FocusNode? focusNode;
  /// When true the surrounding box (background + hairline border) is
  /// not painted — only the text + cursor. Use inside hosts that
  /// already provide their own chrome (e.g. a terminal-style prompt
  /// row that just wants the input to blend in).
  final bool borderless;
  /// Selects the entire current text the moment the input gains
  /// focus. Default `true` — convention for numeric / property-style
  /// inputs where the user types to replace, not to append. Free-form
  /// text editors (e.g. the console prompt where the user might
  /// return to a half-written command) should pass `false`.
  final bool selectAllOnFocus;
  /// When the user presses Esc, restore the controller's text to
  /// whatever it was when focus was gained, then drop focus. Default
  /// `true` — universal "abort edit" gesture. Inputs that have no
  /// committed-vs-draft distinction (the console prompt) can opt out.
  final bool revertOnEscape;

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
    this.focusNode,
    this.borderless = false,
    this.selectAllOnFocus = true,
    this.revertOnEscape = true,
  });

  @override
  State<AtomTextInput> createState() => _AtomTextInputState();
}

class _AtomTextInputState extends State<AtomTextInput> {
  FocusNode? _internalFocus;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocus!;
  bool _hover = false;
  /// Snapshot of [widget.controller.text] the moment focus was
  /// gained. Used by [_onKey] to restore the value on Esc. Cleared
  /// when focus is lost — onSubmit / outside-tap commits the live
  /// value as the new "committed" baseline.
  String? _textOnFocus;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocus = FocusNode();
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AtomTextInput old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (widget.focusNode == null && _internalFocus == null) {
        _internalFocus = FocusNode();
      } else if (widget.focusNode != null) {
        _internalFocus?.dispose();
        _internalFocus = null;
      }
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _internalFocus?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      // Snapshot for Esc-revert and (optionally) select all so the
      // user's first keystroke replaces the value rather than appending
      // to it — same convention as Pro Tools / Reaper inline numerics.
      _textOnFocus = widget.controller.text;
      if (widget.selectAllOnFocus) {
        // Defer one frame: EditableText may install a default selection
        // (collapsed at the tap point) that would race with this assign
        // if we ran it inside the focus listener tick.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_focusNode.hasFocus) return;
          widget.controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.controller.text.length,
          );
        });
      }
    } else {
      _textOnFocus = null;
    }
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.revertOnEscape) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final snapshot = _textOnFocus;
    if (snapshot != null && widget.controller.text != snapshot) {
      widget.controller.value = TextEditingValue(
        text: snapshot,
        selection: TextSelection.collapsed(offset: snapshot.length),
      );
    }
    _focusNode.unfocus();
    return KeyEventResult.handled;
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
          decoration: widget.borderless
              ? null
              : BoxDecoration(
                  color: widget.enabled
                      ? ConsoleSkin.bgDeep
                      : ConsoleSkin.bgRaised,
                  border:
                      Border.all(color: border, width: ConsoleSkin.hairlinePx),
                  borderRadius: BorderRadius.circular(ConsoleSkin.radius),
                ),
          padding: widget.borderless
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          // Wrap EditableText in a Focus so we can intercept Esc for
          // Esc-revert WITHOUT taking focus away (the inner
          // EditableText is the actual focusable). `canRequestFocus:
          // false` keeps the wrapper invisible to focus traversal.
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _onKey,
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
              onSubmitted: (v) {
                // Update the revert baseline on commit so subsequent
                // Esc reverts to the latest committed value, not the
                // original from focus-gain.
                _textOnFocus = v;
                widget.onSubmitted?.call(v);
              },
            ),
          ),
        ),
      ),
    );
  }
}
