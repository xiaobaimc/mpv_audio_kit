import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'command_catalog.dart';

/// Coarse-grained log buckets used by the console's filter chips.
/// Keep these in lock-step with [ConsoleController.passes] — adding
/// a level here without a matching dispatch case will silently hide
/// the new level from the view.
enum LogCategory { error, warn, info, debug }

/// Out-of-tree state for the [ConsolePanel] — owned by `_StudioRoot`
/// so toggling the panel off and on doesn't drop the log buffer.
///
/// Subscribes to the player's engine + library log streams the moment
/// it is attached, captures their entries into a bounded ring (newest
/// at the tail), and exposes a [submit] entry point so the terminal
/// prompt can dispatch commands back to mpv. A REPL-style echo of
/// every submitted command is appended to the same buffer so the
/// user sees their input alongside the engine's response.
///
/// Per-level filter state ([enabled] / [setEnabled]) lives here too
/// so toggling the panel off and on preserves the user's filter
/// selection alongside the buffer.
class ConsoleController extends ChangeNotifier {
  /// Cap so memory stays bounded across long sessions; the oldest
  /// entries are dropped when the cap is hit.
  static const int _maxBuffer = 500;

  final List<MpvLogEntry> _entries = [];
  final List<String> _history = [];
  /// Visible categories. Defaults to all on so a freshly-opened
  /// console doesn't hide anything by surprise.
  final Set<LogCategory> _enabled = {...LogCategory.values};
  StreamSubscription<MpvLogEntry>? _engineSub;
  StreamSubscription<MpvLogEntry>? _libSub;
  Player? _player;

  // ── Autocomplete catalog ──────────────────────────────────────────
  // Fetched once at attach via mpv's runtime introspection. Updated
  // notification fires when the catalog finishes loading so the
  // suggestion popup can transition from "loading…" to the real list.
  List<CmdSpec> _commands = const [];
  List<PropSpec> _properties = const [];
  List<AudioDevice> _audioDevices = const [];
  /// LRU-ish cache of `option-info/<name>` results. Key is the
  /// property name; `null` value means we asked mpv and the prop has
  /// no introspectable option metadata (computed read-only props).
  final Map<String, OptionInfo?> _optionInfoCache = {};
  bool _catalogReady = false;

  List<CmdSpec> get commands => _commands;
  List<PropSpec> get properties => _properties;
  List<AudioDevice> get audioDevices => _audioDevices;
  bool get catalogReady => _catalogReady;

  /// Ordered list of all captured entries (unfiltered). Returned by
  /// reference so the view can iterate without copying; do not mutate.
  List<MpvLogEntry> get entries => _entries;

  /// Submitted commands in submission order. Used by the terminal
  /// prompt's Up / Down history navigation.
  List<String> get history => _history;

  /// True when [category] is currently visible in the console view.
  bool enabled(LogCategory category) => _enabled.contains(category);

  /// Toggles [category]'s visibility and notifies listeners so the
  /// view rebuilds with the new filter.
  void setEnabled(LogCategory category, bool on) {
    final changed = on
        ? _enabled.add(category)
        : _enabled.remove(category);
    if (changed) notifyListeners();
  }

  /// Bucket [entry] into one of the [LogCategory] values, or `null`
  /// when its level falls outside the four presented buckets (e.g.
  /// `LogLevel.off`).
  static LogCategory? categoryOf(MpvLogEntry entry) {
    switch (entry.level) {
      case LogLevel.fatal:
      case LogLevel.error:
        return LogCategory.error;
      case LogLevel.warn:
        return LogCategory.warn;
      case LogLevel.info:
        return LogCategory.info;
      case LogLevel.v:
      case LogLevel.debug:
      case LogLevel.trace:
        return LogCategory.debug;
      case LogLevel.off:
        return null;
    }
  }

  /// True when [entry] should be rendered under the current filter.
  /// REPL-echo entries (`prefix == '>'`) are always shown regardless
  /// of filters — they're the user's own input, hiding them would
  /// orphan the engine's response right below.
  bool passes(MpvLogEntry entry) {
    if (entry.prefix == '>') return true;
    final c = categoryOf(entry);
    return c == null || _enabled.contains(c);
  }

  /// Wires this controller to [player]'s log streams + kicks off the
  /// runtime catalog load. Idempotent — a second call is a no-op so
  /// [didChangeDependencies] can attach safely on every rebuild.
  void attach(Player player) {
    if (_player != null) return;
    _player = player;
    _engineSub = player.stream.log.listen(_append);
    _libSub = player.stream.internalLog.listen(_append);
    _loadCatalog();
  }

  /// Pulls the live command + property + audio-device catalog from
  /// mpv. Each list property serializes as JSON via `MPV_FORMAT_NODE`
  /// → `print_node`; `property-list` is a `STRING_LIST` and comes
  /// back as a comma-joined string (mpv has no current property
  /// name containing a comma, so a plain split is safe).
  Future<void> _loadCatalog() async {
    final p = _player;
    if (p == null) return;

    // command-list
    try {
      final raw = await p.getRawProperty('command-list');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          _commands = list
              .whereType<Map<String, dynamic>>()
              .map(_parseCommand)
              .where((c) => c != null)
              .cast<CmdSpec>()
              .toList(growable: false);
        }
      }
    } catch (_) {
      // Catalog stays empty — autocomplete just shows nothing.
    }

    // property-list
    try {
      final raw = await p.getRawProperty('property-list');
      if (raw != null && raw.isNotEmpty) {
        final names = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
        _properties = names
            .map((n) => PropSpec(
                  name: n,
                  description: curatedPropertyDescriptions[n],
                ))
            .toList(growable: false);
      }
    } catch (_) {}

    await _refreshAudioDevices();

    _catalogReady = true;
    notifyListeners();
  }

  CmdSpec? _parseCommand(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String) return null;
    final rawArgs = json['args'];
    final args = <CmdArg>[];
    if (rawArgs is List) {
      for (final a in rawArgs) {
        if (a is Map<String, dynamic>) {
          final aName = a['name'];
          final aType = a['type'];
          final aOpt = a['optional'];
          if (aName is String && aType is String) {
            args.add(CmdArg(
              name: aName,
              type: aType,
              optional: aOpt == true,
            ));
          }
        }
      }
    }
    return CmdSpec(
      name: name,
      args: args,
      vararg: json['vararg'] == true,
      description: curatedCommandDescriptions[name],
    );
  }

  /// Refreshes [audioDevices] from mpv's `audio-device-list`. Called
  /// at attach time and on demand (subscribers can call this to react
  /// to hot-plug events). Backed by mpv's hotplug instance which
  /// caches internally, so the round-trip is cheap.
  Future<void> _refreshAudioDevices() async {
    final p = _player;
    if (p == null) return;
    try {
      final raw = await p.getRawProperty('audio-device-list');
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _audioDevices = list
          .whereType<Map<String, dynamic>>()
          .map((m) => AudioDevice(
                name: m['name'] as String? ?? '',
                description: m['description'] as String? ?? '',
              ))
          .where((d) => d.name.isNotEmpty)
          .toList(growable: false);
      notifyListeners();
    } catch (_) {}
  }

  /// Fetches `option-info/<name>` for [propName], caching the parsed
  /// [OptionInfo] (or `null` for properties without option metadata).
  /// Subsequent calls for the same property hit the cache and return
  /// synchronously via the future without a round-trip.
  Future<OptionInfo?> getOptionInfo(String propName) async {
    if (_optionInfoCache.containsKey(propName)) {
      return _optionInfoCache[propName];
    }
    final p = _player;
    if (p == null) {
      _optionInfoCache[propName] = null;
      return null;
    }
    try {
      final raw = await p.getRawProperty('option-info/$propName');
      if (raw == null || raw.isEmpty) {
        _optionInfoCache[propName] = null;
        return null;
      }
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        _optionInfoCache[propName] = null;
        return null;
      }
      final info = OptionInfo.fromJson(parsed);
      _optionInfoCache[propName] = info;
      return info;
    } catch (_) {
      _optionInfoCache[propName] = null;
      return null;
    }
  }

  void _append(MpvLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxBuffer) {
      _entries.removeRange(0, _entries.length - _maxBuffer);
    }
    notifyListeners();
  }

  /// Drops every captured entry (does NOT clear command history).
  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  /// Echoes [line] as a `>`-prefixed entry, then dispatches it to
  /// mpv via [Player.sendRawCommand] (whitespace-tokenised). On
  /// failure the error is appended as a `console` error entry so the
  /// user sees what went wrong without having to look elsewhere.
  Future<void> submit(String line) async {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    _history.add(trimmed);
    _append(MpvLogEntry(
      prefix: '>',
      level: LogLevel.info,
      text: trimmed,
    ));
    final p = _player;
    if (p == null) {
      _append(MpvLogEntry(
        prefix: 'console',
        level: LogLevel.error,
        text: 'no player attached',
      ));
      return;
    }
    final args = trimmed.split(RegExp(r'\s+'));
    try {
      await p.sendRawCommand(args);
    } catch (e) {
      _append(MpvLogEntry(
        prefix: 'console',
        level: LogLevel.error,
        text: '$e',
      ));
    }
  }

  @override
  void dispose() {
    _engineSub?.cancel();
    _libSub?.cancel();
    super.dispose();
  }
}
