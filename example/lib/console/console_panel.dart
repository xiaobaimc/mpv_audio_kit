import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_label.dart';
import '../atoms/atom_text_input.dart';
import '../skin/console_skin.dart';
import '../skin/paint_helpers.dart';
import 'console_controller.dart';
import 'suggestion_engine.dart';
import 'suggestion_popup.dart';

/// Bottom-most sidebar in the studio shell — a terminal-style log
/// viewer with an interactive command prompt at the foot.
///
/// All persistent state lives in [ConsoleController] (owned by the
/// shell) so opening / closing the panel doesn't drop the buffer.
/// The view is a thin shell: a header, a scrolling log list, and a
/// `>`-prefixed input line that submits to mpv via
/// [Player.sendRawCommand].
class ConsolePanel extends StatefulWidget {
  final ConsoleController controller;
  const ConsolePanel({super.key, required this.controller});

  @override
  State<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends State<ConsolePanel> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  /// Focus node owned by the log scroll's [SelectableRegion]. Needed
  /// because [SelectableRegion] (the widgets-layer equivalent of
  /// `SelectionArea`, which lives in material) requires an explicit
  /// focus node and can't synthesise its own.
  final FocusNode _selectionFocus = FocusNode(debugLabel: 'console-log-selection');
  final ScrollController _scroll = ScrollController();
  /// Cursor into the controller's history (-1 = "uncommitted draft");
  /// Up arrow walks back, Down arrow walks forward.
  int _historyCursor = -1;
  String _draft = '';

  // ── Autocomplete ──────────────────────────────────────────────────
  late final SuggestionEngine _engine = SuggestionEngine(widget.controller);
  SuggestionResult _suggestions = SuggestionResult.empty;
  int _selectedSuggestion = 0;
  bool _popupOpen = false;
  /// Set right before [_submit] clears the input so the listener-
  /// triggered recompute that follows doesn't immediately re-open
  /// the popup with the full command list (the input becomes empty
  /// post-clear, which would otherwise read as "user is back at the
  /// start, show everything"). Cleared as soon as the user types
  /// the next character.
  bool _suppressNextRecompute = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onLog);
    _input.addListener(_onInputChanged);
    _inputFocus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ConsolePanel old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onLog);
      widget.controller.addListener(_onLog);
    }
  }

  void _onLog() {
    if (!mounted) return;
    // Auto-scroll to the tail when the user is already there. Leaves
    // the view alone when the user is reading older entries so an
    // incoming log line doesn't yank them away.
    final atTail = !_scroll.hasClients ||
        _scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 4;
    setState(() {});
    if (atTail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLog);
    _input.removeListener(_onInputChanged);
    _inputFocus.removeListener(_onFocusChanged);
    _input.dispose();
    _inputFocus.dispose();
    _selectionFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Autocomplete plumbing ────────────────────────────────────────

  void _onFocusChanged() {
    // Closing on blur is unconditional — focus moving away from the
    // prompt should never leave a dangling popup. Opening, on the
    // other hand, is gated on an explicit click ([_onPromptTap])
    // rather than on any focus gain: programmatic focus-restore
    // after a successful submit must NOT re-open the popup, the
    // user wants to read the engine's response in peace.
    if (!_inputFocus.hasFocus) {
      setState(() => _popupOpen = false);
    }
  }

  void _onPromptTap() {
    // Click anywhere inside the prompt row opens the suggestions —
    // the deliberate, user-initiated trigger that brings the popup
    // back after Enter / blur / Esc.
    _recomputeSuggestions();
  }

  void _onInputChanged() {
    if (_suppressNextRecompute) {
      // The listener fired because [_submit] just cleared the input;
      // skip this single tick so the popup stays closed even though
      // the input is now empty (which would otherwise show the full
      // command list as if the user had just focused fresh).
      _suppressNextRecompute = false;
      return;
    }
    _recomputeSuggestions();
  }

  Future<void> _recomputeSuggestions() async {
    final cursor = _input.selection.baseOffset.clamp(0, _input.text.length);
    final result = await _engine.compute(_input.text, cursor);
    if (!mounted) return;
    setState(() {
      _suggestions = result;
      // Keep the highlight valid as the list shrinks under the user's
      // typing; reset to top when the visible set changes substantially.
      if (_selectedSuggestion >= result.suggestions.length) {
        _selectedSuggestion = 0;
      }
      _popupOpen = result.suggestions.isNotEmpty;
    });
  }

  /// Replaces the current token with [s.label] and advances the
  /// cursor (adding a space) when the suggestion expects one. Then
  /// recomputes suggestions for the now-current token, which is
  /// what makes `set [TAB] vol [TAB]` flow naturally to the next
  /// step every time. Informational rows (placeholders like
  /// `<target>`) are no-ops — they're meant to be read, not
  /// inserted, so Tab / click on them keeps focus on the prompt
  /// without touching the input.
  void _completeWith(Suggestion s) {
    if (s.informational) {
      _inputFocus.requestFocus();
      return;
    }
    final text = _input.text;
    final start = _suggestions.tokenStart;
    final end = _suggestions.tokenEnd;
    final replacement = s.advanceCursor ? '${s.label} ' : s.label;
    final newText = text.replaceRange(start, end, replacement);
    final newCursor = start + replacement.length;
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _selectedSuggestion = 0;
    _inputFocus.requestFocus();
    // [_onInputChanged] is already wired through the listener so the
    // popup will re-render with the next-context suggestions.
  }

  Future<void> _submit(String line) async {
    if (line.trim().isEmpty) {
      _input.clear();
      return;
    }
    setState(() => _popupOpen = false);
    await widget.controller.submit(line);
    // Skip the recompute that the upcoming `clear()` will trigger so
    // the popup doesn't pop straight back open with the command list.
    _suppressNextRecompute = true;
    _input.clear();
    _historyCursor = -1;
    _draft = '';
    // Keep focus on the prompt so the user can keep typing.
    _inputFocus.requestFocus();
  }

  /// Keyboard handling. Three layers, in priority order:
  ///   1. Suggestion popup — Up / Down navigate, Tab completes, Esc
  ///      dismisses. Active when [_suggestions] has results.
  ///   2. Command history — Up / Down walk through prior submitted
  ///      commands. Active when popup is closed.
  ///   3. Default — fall through to the input widget.
  ///
  /// Enter is NOT intercepted here; [AtomTextInput] surfaces it via
  /// [onSubmitted] and we run [_submit] (which closes the popup).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Layer 1: popup-aware navigation.
    if (_popupOpen && _suggestions.suggestions.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedSuggestion =
              (_selectedSuggestion + 1) % _suggestions.suggestions.length;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedSuggestion = (_selectedSuggestion - 1 +
                  _suggestions.suggestions.length) %
              _suggestions.suggestions.length;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _completeWith(_suggestions.suggestions[_selectedSuggestion]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _popupOpen = false);
        return KeyEventResult.handled;
      }
    }

    // Layer 2: command-history navigation.
    final history = widget.controller.history;
    if (history.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_historyCursor == -1) {
        _draft = _input.text;
        _historyCursor = history.length - 1;
      } else if (_historyCursor > 0) {
        _historyCursor--;
      } else {
        return KeyEventResult.handled;
      }
      _setInput(history[_historyCursor]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_historyCursor == -1) return KeyEventResult.ignored;
      _historyCursor++;
      if (_historyCursor >= history.length) {
        _historyCursor = -1;
        _setInput(_draft);
      } else {
        _setInput(history[_historyCursor]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setInput(String value) {
    _input.text = value;
    _input.selection = TextSelection.collapsed(offset: value.length);
  }

  /// Serialise the visible log entries to plain text and push to the
  /// clipboard. Each line uses the same `prefix · level · text` format
  /// the on-screen rendering shows; echo-of-command lines keep just
  /// `> text` so a copy → paste roundtrip stays runnable.
  Future<void> _copyVisible(List<MpvLogEntry> visible) async {
    if (visible.isEmpty) return;
    final buf = StringBuffer();
    for (final e in visible) {
      if (e.prefix == '>') {
        buf.writeln('> ${e.text}');
      } else {
        buf.writeln('${e.prefix} ${e.level.mpvValue} ${e.text}');
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final visible =
        ctrl.entries.where(ctrl.passes).toList(growable: false);
    // Stack is rooted in the console panel itself so the autocomplete
    // popup is constrained to the console's bounds: its width = the
    // console's width, its height capped by the console's height
    // minus the prompt row. No global Overlay involved.
    return Container(
      color: ConsoleSkin.bgDeep,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                controller: ctrl,
                visibleCount: visible.length,
                totalCount: ctrl.entries.length,
                onClear: ctrl.clear,
                onCopy: () => _copyVisible(visible),
              ),
              const _Hairline(),
              Expanded(
                // SelectableRegion = the widgets-layer twin of
                // SelectionArea (which is material-only). System
                // shortcut Cmd+C / Ctrl+C copies the current selection
                // by default; emptyTextSelectionControls suppresses the
                // touch-style toolbar — we don't want it on a desktop
                // console panel.
                child: SelectableRegion(
                  focusNode: _selectionFocus,
                  selectionControls: emptyTextSelectionControls,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: visible.length,
                    itemBuilder: (ctx, i) => _LogLine(entry: visible[i]),
                  ),
                ),
              ),
              const _Hairline(),
              // Translucent listener so the click both opens the
              // suggestion popup AND falls through to the input's
              // own gesture handler (focus + cursor placement).
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _onPromptTap(),
                child: _Prompt(
                  controller: _input,
                  focusNode: _inputFocus,
                  onSubmitted: _submit,
                  onKeyEvent: _onKey,
                ),
              ),
            ],
          ),
          if (_popupOpen && _suggestions.suggestions.isNotEmpty)
            // Bounded to the log area: top of the bottom edge of the
            // header (28 + 1 hairline), bottom of the top edge of the
            // prompt (24 + 1 hairline). Inside that, [Align] lets the
            // popup shrink-wrap to content height when shorter and
            // pin to the bottom (just above the prompt) so it grows
            // upward toward the header instead of spreading.
            Positioned(
              left: 0,
              right: 0,
              top: 29,
              bottom: 25,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SuggestionPopup(
                  suggestions: _suggestions.suggestions,
                  selectedIndex: _selectedSuggestion,
                  tokenSoFar: _suggestions.tokenSoFar,
                  onHover: (i) {
                    if (i == _selectedSuggestion) return;
                    setState(() => _selectedSuggestion = i);
                  },
                  onTap: _completeWith,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ConsoleController controller;
  final int visibleCount;
  final int totalCount;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  const _Header({
    required this.controller,
    required this.visibleCount,
    required this.totalCount,
    required this.onClear,
    required this.onCopy,
  });

  String get _clearLabel {
    if (totalCount == 0) return 'clear';
    if (visibleCount == totalCount) return 'clear $totalCount';
    return 'clear $visibleCount / $totalCount';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const AtomLabel(
              'CONSOLE',
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.accent,
              mono: true,
              letterSpacing: 1.5,
              weight: FontWeight.w500,
            ),
            const SizedBox(width: 12),
            _FilterChip(
              label: 'ERROR',
              color: ConsoleSkin.meterRed,
              active: controller.enabled(LogCategory.error),
              onTap: () => controller.setEnabled(
                LogCategory.error,
                !controller.enabled(LogCategory.error),
              ),
            ),
            _FilterChip(
              label: 'WARN',
              color: ConsoleSkin.meterAmber,
              active: controller.enabled(LogCategory.warn),
              onTap: () => controller.setEnabled(
                LogCategory.warn,
                !controller.enabled(LogCategory.warn),
              ),
            ),
            _FilterChip(
              label: 'INFO',
              color: ConsoleSkin.meterCyan,
              active: controller.enabled(LogCategory.info),
              onTap: () => controller.setEnabled(
                LogCategory.info,
                !controller.enabled(LogCategory.info),
              ),
            ),
            _FilterChip(
              label: 'DEBUG',
              color: ConsoleSkin.fgDim,
              active: controller.enabled(LogCategory.debug),
              onTap: () => controller.setEnabled(
                LogCategory.debug,
                !controller.enabled(LogCategory.debug),
              ),
            ),
            const Spacer(),
            _HeaderTextButton(
              label: 'copy',
              enabled: visibleCount > 0,
              onTap: onCopy,
            ),
            _HeaderTextButton(label: _clearLabel, onTap: onClear),
          ],
        ),
      ),
    );
  }
}

/// Toggleable filter chip — text-only badge. Active = label in the
/// level colour (red / amber / cyan / dim). Inactive = label faint.
/// Hover lifts an inactive chip from `fgFaint` to `fgDim` so it reads
/// as clickable.
class _FilterChip extends StatefulWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.active
        ? widget.color
        : (_hover ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AtomLabel(
            widget.label,
            fontSize: ConsoleSkin.sizeTiny,
            color: fg,
            mono: true,
            letterSpacing: 0.8,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Small text-only button used in the console header (`copy`, `clear`).
/// Hover lifts the label from `fgDim` to `fg`; disabled keeps it
/// `fgFaint` and ignores clicks so a copy on an empty buffer doesn't
/// look like it did anything.
class _HeaderTextButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  const _HeaderTextButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_HeaderTextButton> createState() => _HeaderTextButtonState();
}

class _HeaderTextButtonState extends State<_HeaderTextButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = !widget.enabled
        ? ConsoleSkin.fgFaint
        : (_hover ? ConsoleSkin.fg : ConsoleSkin.fgDim);
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.enabled ? (_) => widget.onTap() : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AtomLabel(
            widget.label,
            fontSize: ConsoleSkin.sizeTiny,
            color: color,
            mono: true,
          ),
        ),
      ),
    );
  }
}

// ─── Prompt ───────────────────────────────────────────────────────────

class _Prompt extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final FocusOnKeyEventCallback onKeyEvent;

  const _Prompt({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const AtomLabel(
              '>',
              fontSize: ConsoleSkin.sizeSmall,
              color: ConsoleSkin.accent,
              mono: true,
              weight: FontWeight.w600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Focus(
                onKeyEvent: onKeyEvent,
                child: AtomTextInput(
                  controller: controller,
                  focusNode: focusNode,
                  width: null,
                  mono: true,
                  borderless: true,
                  onSubmitted: onSubmitted,
                  // The console prompt is a free-form draft area —
                  // selecting all on focus and reverting on Esc would
                  // both surprise the user (focus is stolen and
                  // restored across submit / blur).
                  selectAllOnFocus: false,
                  revertOnEscape: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Log line ─────────────────────────────────────────────────────────

/// One line in the console log. Renders via a single `Text.rich` so
/// the wrapping [SelectionArea] in the parent can drag-select across
/// lines (the previous CustomPaint version drew glyphs straight onto
/// the canvas, which the selection machinery has no hooks into).
///
/// Layout: `prefix · level · text`. Echo-of-command lines (prefix
/// `>`) drop the level and render the body in accent so they read
/// like a shell prompt rather than a log entry.
class _LogLine extends StatelessWidget {
  final MpvLogEntry entry;
  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isCommand = entry.prefix == '>';
    final bodyColor = _colorFor(entry.level, entry.prefix);
    final prefixColor =
        isCommand ? ConsoleSkin.accent : ConsoleSkin.fgFaint;
    const baseStyle = TextStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
      height: 1.3,
    );
    return SizedBox(
      height: 16,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.prefix} ',
              style: baseStyle.copyWith(color: prefixColor),
            ),
            if (!isCommand)
              TextSpan(
                text: '${entry.level.mpvValue} ',
                style: baseStyle.copyWith(color: ConsoleSkin.fgDim),
              ),
            TextSpan(
              text: entry.text,
              style: baseStyle.copyWith(color: bodyColor),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
      ),
    );
  }

  static Color _colorFor(LogLevel level, String prefix) {
    // Echo of a submitted command — rendered in the accent so it
    // stands out in the log scroll.
    if (prefix == '>') return ConsoleSkin.accent;
    switch (level) {
      case LogLevel.fatal:
      case LogLevel.error:
        return ConsoleSkin.meterRed;
      case LogLevel.warn:
        return ConsoleSkin.meterAmber;
      case LogLevel.info:
        return ConsoleSkin.meterCyan;
      case LogLevel.v:
      case LogLevel.debug:
      case LogLevel.trace:
        return ConsoleSkin.fgDim;
      case LogLevel.off:
        return ConsoleSkin.fgFaint;
    }
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Container(
        height: ConsoleSkin.hairlinePx,
        color: ConsoleSkin.hairline,
      );
}

// Silence unused-import lint when this module is iterated on.
// ignore: unused_element
void _kindle(Canvas c, Rect r) =>
    box(c, r, fill: ConsoleSkin.bgDeep, border: ConsoleSkin.hairline);
