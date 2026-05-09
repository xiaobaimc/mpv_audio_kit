import 'command_catalog.dart';
import 'console_controller.dart';

/// One row in the autocomplete popup.
class Suggestion {
  /// The text to insert in place of the current token when the user
  /// completes this suggestion (Tab / click).
  final String label;
  /// Short syntax / range hint shown in the dim middle column. Used
  /// for property metadata (`0..100`, `default`); command signatures
  /// use [args] + [activeArgIndex] instead so individual args can be
  /// coloured by position.
  final String? hint;
  /// Human-readable one-liner shown in the dim right column.
  final String? description;
  final SuggestionKind kind;
  /// True when [label] should be followed by a space on completion
  /// (because a next token is meaningful: e.g. `set` → property,
  /// `set volume` → value). Terminal commands like `quit` set this
  /// to false so the user can hit Enter immediately.
  final bool advanceCursor;
  /// True when this row is purely informational — the popup keeps it
  /// on screen but Tab / click are no-ops. Used by the signature
  /// helper row that stays anchored while the user types args.
  final bool informational;
  /// When set, the popup renders each arg as its own span and tints
  /// the one at [activeArgIndex] in accent. Used by both command
  /// suggestions (with `activeArgIndex == null` while still typing
  /// the verb) and by the signature helper that follows the user
  /// through each arg position.
  final List<CmdArg>? args;
  final int? activeArgIndex;

  const Suggestion({
    required this.label,
    this.hint,
    this.description,
    required this.kind,
    this.advanceCursor = true,
    this.informational = false,
    this.args,
    this.activeArgIndex,
  });
}

enum SuggestionKind { command, property, value }

/// Result of [SuggestionEngine.compute]: the matching suggestions
/// plus the byte range in the input string that the matched token
/// occupies (so the popup can replace just that token on
/// completion).
class SuggestionResult {
  final List<Suggestion> suggestions;
  /// First character of the current token (the one being completed)
  /// in the input string. Inclusive.
  final int tokenStart;
  /// One-past-last character of the current token. Exclusive.
  final int tokenEnd;
  /// The current partial token text — the popup uses this to bold
  /// the matching prefix in each suggestion.
  final String tokenSoFar;

  const SuggestionResult({
    required this.suggestions,
    required this.tokenStart,
    required this.tokenEnd,
    required this.tokenSoFar,
  });

  static const empty = SuggestionResult(
    suggestions: <Suggestion>[],
    tokenStart: 0,
    tokenEnd: 0,
    tokenSoFar: '',
  );

  bool get isEmpty => suggestions.isEmpty;
}

/// Computes context-aware autocomplete suggestions. Three contexts:
///   1. typing the verb       → mpv's full command list
///   2. typing the 2nd token after `set / cycle / add / multiply`
///                            → mpv's full property list
///   3. typing the 3rd token after `set <prop>`
///                            → values from `option-info/<prop>`,
///                              or the audio-device-list for
///                              `audio-device`, or an empty list
///                              for free-form properties
class SuggestionEngine {
  final ConsoleController controller;
  SuggestionEngine(this.controller);

  Future<SuggestionResult> compute(String input, int cursor) async {
    final upTo = input.substring(0, cursor.clamp(0, input.length));
    final tokens = _tokenize(upTo);
    final last = tokens.isEmpty
        ? const _Token('', 0, 0)
        : tokens.last;

    // Context 1: first token (or no tokens yet).
    if (tokens.length <= 1 && !upTo.endsWith(' ')) {
      return SuggestionResult(
        suggestions: _filterCommands(last.text),
        tokenStart: last.start,
        tokenEnd: last.end,
        tokenSoFar: last.text,
      );
    }

    // Context 2: 2nd token after a property-taking command.
    final cmd = tokens[0].text;
    if (propertyTakingCommands.contains(cmd) &&
        (tokens.length == 1 ||
            (tokens.length == 2 && !upTo.endsWith(' ')))) {
      // The 2nd token may be empty if input ends with a space —
      // in that case `tokens.last` is still the verb; synthesize
      // an empty token at end-of-input.
      final partial = tokens.length == 2 ? last.text : '';
      final start = tokens.length == 2 ? last.start : upTo.length;
      final end = tokens.length == 2 ? last.end : upTo.length;
      return SuggestionResult(
        suggestions: _filterProperties(partial),
        tokenStart: start,
        tokenEnd: end,
        tokenSoFar: partial,
      );
    }

    // Context 3: 3rd token after `set <prop>`.
    if (valueTakingCommands.contains(cmd) &&
        tokens.length >= 2 &&
        (tokens.length == 2 ||
            (tokens.length == 3 && !upTo.endsWith(' ')))) {
      final propName = tokens[1].text;
      final partial = tokens.length == 3 ? last.text : '';
      final start = tokens.length == 3 ? last.start : upTo.length;
      final end = tokens.length == 3 ? last.end : upTo.length;
      final values = await _filterValues(propName, partial);
      return SuggestionResult(
        suggestions: values,
        tokenStart: start,
        tokenEnd: end,
        tokenSoFar: partial,
      );
    }

    // Context 4: signature helper. Once the user is past the verb
    // and into arg territory, the popup keeps a single non-clickable
    // row anchored that shows the command + every arg, with the
    // currently-active arg painted in accent. The user reads it and
    // types the value; no value enumeration, no filtering — just a
    // visual "you are here" cursor that follows each space.
    final hasTrailing = upTo.endsWith(' ');
    final argIndex = hasTrailing ? tokens.length - 1 : tokens.length - 2;
    if (argIndex >= 0) {
      // Skip cases already covered by Context 2 / 3.
      final isProp2 =
          propertyTakingCommands.contains(cmd) && argIndex == 0;
      final isValue3 =
          valueTakingCommands.contains(cmd) && argIndex == 1;
      if (!isProp2 && !isValue3) {
        final cmdSpec = _findCommand(cmd);
        if (cmdSpec != null && cmdSpec.args.isNotEmpty) {
          var idx = argIndex;
          if (idx >= cmdSpec.args.length && cmdSpec.vararg) {
            idx = cmdSpec.args.length - 1;
          }
          if (idx >= 0 && idx < cmdSpec.args.length) {
            final partial = hasTrailing ? '' : last.text;
            final start = hasTrailing ? upTo.length : last.start;
            final end = hasTrailing ? upTo.length : last.end;
            return SuggestionResult(
              suggestions: [
                Suggestion(
                  label: cmd,
                  description: cmdSpec.description,
                  kind: SuggestionKind.command,
                  args: cmdSpec.args,
                  activeArgIndex: idx,
                  informational: true,
                ),
              ],
              tokenStart: start,
              tokenEnd: end,
              tokenSoFar: partial,
            );
          }
        }
      }
    }

    return SuggestionResult.empty;
  }

  CmdSpec? _findCommand(String name) {
    for (final c in controller.commands) {
      if (c.name == name) return c;
    }
    return null;
  }

  // ── Filters / ranking ──────────────────────────────────────────────

  List<Suggestion> _filterCommands(String filter) {
    final cs = controller.commands;
    if (cs.isEmpty) return const [];
    final lower = filter.toLowerCase();
    final matches = <_Scored<Suggestion>>[];
    for (final c in cs) {
      final score = _score(c.name, lower);
      if (score < 0) continue;
      matches.add(_Scored(
        score,
        Suggestion(
          label: c.name,
          description: c.description,
          kind: SuggestionKind.command,
          // The verb always takes at least one space after it when
          // the command has args, otherwise the user can submit
          // immediately (terminal verbs like `quit`, `stop`).
          advanceCursor: c.args.isNotEmpty || c.vararg,
          // Pass args so the popup can render each as its own span.
          // No active highlight while the user is still typing the
          // verb — coloring only kicks in once we're in arg context.
          args: c.args.isEmpty ? null : c.args,
          activeArgIndex: null,
        ),
      ));
    }
    matches.sort();
    return matches.map((m) => m.value).toList(growable: false);
  }

  List<Suggestion> _filterProperties(String filter) {
    final ps = controller.properties;
    if (ps.isEmpty) return const [];
    final lower = filter.toLowerCase();
    final matches = <_Scored<Suggestion>>[];
    for (final p in ps) {
      final score = _score(p.name, lower);
      if (score < 0) continue;
      matches.add(_Scored(
        score,
        Suggestion(
          label: p.name,
          description: p.description,
          kind: SuggestionKind.property,
          advanceCursor: true, // property is followed by a value
        ),
      ));
    }
    matches.sort();
    return matches.map((m) => m.value).toList(growable: false);
  }

  Future<List<Suggestion>> _filterValues(
      String propName, String filter) async {
    final lower = filter.toLowerCase();
    final values = <Suggestion>[];

    // Special case: real OS device names for `audio-device`. The
    // option-info would list "auto" + a placeholder, but the live
    // hotplug list is what the user actually wants.
    if (propName == 'audio-device') {
      for (final d in controller.audioDevices) {
        values.add(Suggestion(
          label: d.name,
          description: d.description,
          kind: SuggestionKind.value,
          advanceCursor: false,
        ));
      }
    }

    // Generic introspection for everything else (and supplementary
    // values for audio-device too — `auto` is in option-info but not
    // in the device list).
    final info = await controller.getOptionInfo(propName);
    if (info != null) {
      // Choice / Object settings list: enumerate.
      if (info.choices != null && info.choices!.isNotEmpty) {
        for (final c in info.choices!) {
          if (values.any((s) => s.label == c)) continue;
          values.add(Suggestion(
            label: c,
            kind: SuggestionKind.value,
            advanceCursor: false,
          ));
        }
      }
      // Numeric: show min / mid / max as quick-pick anchors.
      if (info.min != null && info.max != null) {
        final min = info.min!;
        final max = info.max!;
        final mid = ((min + max) / 2);
        for (final v in [min, mid, max]) {
          final s = _formatNumber(v);
          if (values.any((x) => x.label == s)) continue;
          values.add(Suggestion(
            label: s,
            hint: 'range ${_formatNumber(min)}..${_formatNumber(max)}',
            kind: SuggestionKind.value,
            advanceCursor: false,
          ));
        }
      } else if (info.min != null) {
        values.add(Suggestion(
          label: _formatNumber(info.min!),
          hint: 'min ${_formatNumber(info.min!)}',
          kind: SuggestionKind.value,
          advanceCursor: false,
        ));
      } else if (info.max != null) {
        values.add(Suggestion(
          label: _formatNumber(info.max!),
          hint: 'max ${_formatNumber(info.max!)}',
          kind: SuggestionKind.value,
          advanceCursor: false,
        ));
      }
      // Default value as a reset hint, only if not already present.
      final dv = info.defaultValue;
      if (dv != null) {
        final s = '$dv';
        if (s.isNotEmpty && !values.any((x) => x.label == s)) {
          values.add(Suggestion(
            label: s,
            hint: 'default',
            kind: SuggestionKind.value,
            advanceCursor: false,
          ));
        }
      }
    }

    if (values.isEmpty) return const [];

    final matches = <_Scored<Suggestion>>[];
    for (final v in values) {
      final score = _score(v.label, lower);
      if (score < 0) continue;
      matches.add(_Scored(score, v));
    }
    matches.sort();
    return matches.map((m) => m.value).toList(growable: false);
  }

  // ── Scoring ────────────────────────────────────────────────────────

  /// Returns a sortable score for [name] against [filter] (already
  /// lowercased). Lower is better. Returns -1 when [name] doesn't
  /// match at all, so it can be filtered out.
  ///
  /// Ranking:
  ///   0   exact match
  ///   1   prefix match
  ///   2   word boundary match (e.g. "vol" in "audio-volume")
  ///   3   substring match
  static int _score(String name, String filter) {
    if (filter.isEmpty) return 100;
    final lower = name.toLowerCase();
    if (lower == filter) return 0;
    if (lower.startsWith(filter)) return 1;
    // Word-boundary: matches start of any '-'-separated component.
    for (final part in lower.split('-')) {
      if (part.startsWith(filter)) return 2;
    }
    final idx = lower.indexOf(filter);
    if (idx >= 0) return 3 + idx;
    return -1;
  }

  static String _formatNumber(num v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class _Token {
  final String text;
  final int start;
  final int end;
  const _Token(this.text, this.start, this.end);
}

/// Splits [text] into whitespace-separated tokens, preserving each
/// token's position in the original string so the autocomplete can
/// replace the matched range cleanly. Quoted tokens are NOT honored
/// — mpv's command-line accepts quoted args but for autocomplete we
/// only need to recognise the token boundaries.
List<_Token> _tokenize(String text) {
  final tokens = <_Token>[];
  int i = 0;
  while (i < text.length) {
    while (i < text.length && text[i] == ' ') {
      i++;
    }
    if (i >= text.length) break;
    final start = i;
    while (i < text.length && text[i] != ' ') {
      i++;
    }
    tokens.add(_Token(text.substring(start, i), start, i));
  }
  return tokens;
}

class _Scored<T> implements Comparable<_Scored<T>> {
  final int score;
  final T value;
  const _Scored(this.score, this.value);
  @override
  int compareTo(_Scored<T> other) => score - other.score;
}
