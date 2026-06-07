// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'event_isolate.dart';

// ── Events: isolate → main ───────────────────────────────────────────────────

/// Base type for every message the event isolate forwards to the main
/// isolate after init: one subclass per mpv event the player consumes.
sealed class MpvIsolateEvent {}

/// mpv fired MPV_EVENT_START_FILE — a `loadfile` began opening the
/// next entry (fires even if the open ultimately fails).
class MpvEventStartFile extends MpvIsolateEvent {}

/// mpv fired MPV_EVENT_FILE_LOADED — the current file is open and its
/// metadata / track list is available.
class MpvEventFileLoaded extends MpvIsolateEvent {}

/// mpv fired MPV_EVENT_SEEK — a seek request was accepted and playback
/// has been suspended while mpv reinitializes its pipeline.
class MpvEventPlaybackSeek extends MpvIsolateEvent {}

/// mpv fired MPV_EVENT_PLAYBACK_RESTART — the seek (or file load) has
/// finished reinitializing and playback is about to resume.
/// This is the authoritative "seek request is finished" signal.
class MpvEventPlaybackRestart extends MpvIsolateEvent {}

/// mpv fired MPV_EVENT_END_FILE — playback of the current entry ended.
class MpvEndFileEvent extends MpvIsolateEvent {
  /// The `MPV_END_FILE_REASON_*` code (EOF, stop, error, redirect, …).
  final int reason;

  /// The mpv error code when [reason] is the error reason, else `0`.
  final int error;

  /// Carries the end-of-file [reason] and [error] codes.
  MpvEndFileEvent(this.reason, this.error);
}

/// mpv fired MPV_EVENT_SHUTDOWN — the core is tearing down and the
/// event loop is about to exit.
class MpvEventShutdown extends MpvIsolateEvent {}

/// A `MPV_FORMAT_DOUBLE` property change (e.g. `time-pos`, `volume`).
class MpvEventPropertyDouble extends MpvIsolateEvent {
  /// The mpv property name that changed.
  final String name;

  /// The new value.
  final double value;

  /// Carries the changed property [name] and its new double [value].
  MpvEventPropertyDouble(this.name, this.value);
}

/// A `MPV_FORMAT_FLAG` or `MPV_FORMAT_INT64` property change, both
/// delivered as a Dart [int].
class MpvEventPropertyInt extends MpvIsolateEvent {
  /// The mpv property name that changed.
  final String name;

  /// The new value (a flag is `0` / `1`).
  final int value;

  /// Carries the changed property [name] and its new int [value].
  MpvEventPropertyInt(this.name, this.value);
}

/// A `MPV_FORMAT_STRING` property change.
class MpvEventPropertyString extends MpvIsolateEvent {
  /// The mpv property name that changed.
  final String name;

  /// The new value.
  final String value;

  /// Carries the changed property [name] and its new string [value].
  MpvEventPropertyString(this.name, this.value);
}

/// mpv emitted a property change with `MPV_FORMAT_NODE`. [value] is the
/// recursively-decoded tree: `Map<String, dynamic>` for `MPV_FORMAT_NODE_MAP`,
/// `List<dynamic>` for `MPV_FORMAT_NODE_ARRAY`, a primitive (`String`, `int`,
/// `double`, `bool`), `Uint8List` for `MPV_FORMAT_BYTE_ARRAY`, or `null` for
/// `MPV_FORMAT_NONE`.
class MpvEventPropertyNode extends MpvIsolateEvent {
  /// The mpv property name that changed.
  final String name;

  /// The recursively-decoded node tree (see the class doc for the
  /// possible Dart shapes).
  final dynamic value;

  /// Carries the changed property [name] and its decoded [value] tree.
  MpvEventPropertyNode(this.name, this.value);
}

/// mpv emitted a log line (MPV_EVENT_LOG_MESSAGE) at or above the
/// requested log level.
class MpvEventLog extends MpvIsolateEvent {
  /// The mpv module that produced the line (e.g. `ao`, `ffmpeg`).
  final String prefix;

  /// The mpv log level (`error`, `warn`, `info`, …).
  final String level;

  /// The message text, trailing whitespace stripped.
  final String text;

  /// Carries a single log line's [prefix], [level] and [text].
  MpvEventLog(this.prefix, this.level, this.text);
}

/// mpv reached a hook (MPV_EVENT_HOOK) the player registered. The main
/// isolate must acknowledge it via `mpv_hook_continue` so mpv proceeds.
class MpvEventHookFired extends MpvIsolateEvent {
  /// The hook id to pass back to `mpv_hook_continue`.
  final int id;

  /// The hook name (e.g. `on_load`, `on_unload`).
  final String name;

  /// Carries the fired hook's [id] and [name].
  MpvEventHookFired(this.id, this.name);
}
