// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../player.dart';

/// Low-level native bridge: the raw property / command FFI calls every
/// typed setter funnels through, the `chapter-list` NODE writer, and the
/// mpv error-string lookup. Declared `on _PlayerBase` so the constructor,
/// `dispose`, and the domain mixins can reach these across part boundaries
/// (their abstract signatures live on `_PlayerBase`).
mixin _FfiModule on _PlayerBase {
  /// Writes a property and throws [MpvException] on rejection.
  ///
  /// All typed setters (setVolume, setRate, setAudioEffects, …) flow
  /// through this method. Errors are surfaced rather than swallowed so
  /// the caller can react (out-of-range value, unknown name, malformed
  /// `af` chain after `AudioEffects.custom`, etc.). `_propRc` is the
  /// rc-returning variant for the few call sites that need to tolerate
  /// failures explicitly.
  @override
  void _prop(String name, String value) {
    final rc = _propRc(name, value);
    if (rc < 0) {
      throw MpvException(name: name, code: rc, message: _errorString(rc));
    }
  }

  @override
  int _propRc(String name, String value) {
    return using(
      (arena) => _lib.mpvSetPropertyString(
        _handle,
        name.toNativeUtf8(allocator: arena),
        value.toNativeUtf8(allocator: arena),
      ),
    );
  }

  @override
  int _command(List<String> args) {
    return using((arena) {
      final arr = arena<Pointer<Utf8>>(args.length + 1);
      for (var i = 0; i < args.length; i++) {
        arr[i] = args[i].toNativeUtf8(allocator: arena);
      }
      arr[args.length] = nullptr;
      return _lib.mpvCommand(_handle, arr);
    });
  }

  /// Writes [chapters] to mpv's `chapter-list` — a NODE-array property — via
  /// the stable `mpv_set_property` C API, returning the raw mpv rc.
  ///
  /// `chapter-list` is an array of maps `{title: string, time: double secs}`.
  /// The whole node tree is built in an [Arena]; mpv deep-copies it during
  /// `set_property`, so every allocation is freed on return. An empty list
  /// writes an empty array (clears the chapters).
  @override
  int _setChapterListNode(List<Chapter> chapters) {
    return using((arena) {
      final n = chapters.length;
      final arrayList = arena<MpvNodeList>();
      arrayList.ref.num = n;
      // Arrays carry no keys (maps do); leave them null.
      arrayList.ref.keys = nullptr;
      if (n > 0) {
        final elements = arena<MpvNode>(n);
        for (var i = 0; i < n; i++) {
          final ch = chapters[i];
          // Two map entries per chapter: title (string) + time (double secs).
          final entryValues = arena<MpvNode>(2);
          final entryKeys = arena<Pointer<Utf8>>(2);

          entryKeys[0] = 'title'.toNativeUtf8(allocator: arena);
          entryValues[0].format = MpvFormat.mpvFormatString;
          entryValues[0].u.string =
              (ch.title ?? '').toNativeUtf8(allocator: arena);

          entryKeys[1] = 'time'.toNativeUtf8(allocator: arena);
          entryValues[1].format = MpvFormat.mpvFormatDouble;
          entryValues[1].u.double_ = ch.time.inMicroseconds / 1e6;

          final map = arena<MpvNodeList>();
          map.ref.num = 2;
          map.ref.values = entryValues;
          map.ref.keys = entryKeys;

          elements[i].format = MpvFormat.mpvFormatNodeMap;
          elements[i].u.list = map;
        }
        arrayList.ref.values = elements;
      } else {
        arrayList.ref.values = nullptr;
      }

      final root = arena<MpvNode>();
      root.ref.format = MpvFormat.mpvFormatNodeArray;
      root.ref.u.list = arrayList;

      return _lib.mpvSetProperty(
        _handle,
        'chapter-list'.toNativeUtf8(allocator: arena),
        MpvFormat.mpvFormatNode,
        root.cast<Void>(),
      );
    });
  }

  @override
  String _errorString(int code) {
    final p = _lib.mpvErrorString(code);
    return p == nullptr ? 'error $code' : p.cast<Utf8>().toDartString();
  }

  // ── Public raw escape hatches ────────────────────────────────────────────

  /// Reads any mpv property as a string.
  ///
  /// **Escape hatch for properties not surfaced by the typed API.** For
  /// observed properties (`volume`, `pause`, `cache-secs`, …), prefer
  /// `player.state.<field>` — the cached value is updated on every
  /// property-change event from mpv and avoids an FFI round-trip.
  ///
  /// Returns `null` if the property doesn't exist or the FFI call
  /// fails. Throws [StateError] if the player has been disposed.
  Future<String?> getRawProperty(String name) async {
    _checkNotDisposed();
    await _ready;
    return using((arena) {
      final n = name.toNativeUtf8(allocator: arena);
      final ptr = _lib.mpvGetPropertyString(_handle, n);
      if (ptr == nullptr) {
        return null;
      }
      final s = ptr.cast<Utf8>().toDartString();
      _lib.mpvFree(ptr.cast());
      return s;
    });
  }

  /// Writes any mpv property as a string.
  ///
  /// **Warning:** this is an escape hatch for properties the typed API
  /// doesn't yet cover. If [name] is one of the registry-observed
  /// properties (volume, cache-*, replaygain*, ao, …), the
  /// resulting state mutation will *also* flow through the property
  /// observer on mpv's side, so `player.state` and `player.stream` will
  /// stay consistent — but expect a one-event-loop-tick delay between
  /// the call returning and the cached state catching up. Prefer the
  /// typed setters (`setVolume`, `setCache`, `setReplayGain`, …) when
  /// they exist, both for type-safety and for synchronous state update.
  ///
  /// Two properties are reserved and rejected:
  /// - `af` — owned by the typed [AudioEffects] bundle (including raw
  ///   passthroughs via [AudioEffects.custom]); a raw write would silently
  ///   desync `state.audioEffects`. Use [setAudioEffects] /
  ///   [updateAudioEffects].
  /// - `pause` — owned by the transport intent axis. It is deliberately not
  ///   observed (see [PlayerState.playWhenReady]), so a raw write would
  ///   change actual playback while leaving `state.playWhenReady` (and the
  ///   OS play/pause button bound to it) reporting the old intent. Use
  ///   [play] / [pause].
  ///
  /// Throws [StateError] if the player has been disposed,
  /// [ArgumentError] if [name] is reserved, or [MpvException] if mpv
  /// rejects the property write (unknown name, out-of-range value, etc.).
  Future<void> setRawProperty(String name, String value) async {
    _checkNotDisposed();
    await _ready;
    if (name == 'af') {
      throw ArgumentError.value(
        name,
        'name',
        'Property `af` is owned by the typed AudioEffects bundle. '
            'Use Player.setAudioEffects / updateAudioEffects, and pass '
            'experimental or expression-based filters via '
            'AudioEffects.custom.',
      );
    }
    if (name == 'pause') {
      throw ArgumentError.value(
        name,
        'name',
        'Property `pause` is owned by the transport intent axis and is not '
            'observed, so a raw write would desync state.playWhenReady (and '
            'the OS play/pause button) from actual playback. '
            'Use Player.play() / Player.pause() instead.',
      );
    }
    _prop(name, value);
  }

  /// Sends a raw mpv command.
  ///
  /// **Escape hatch.** Same caveats as [setRawProperty]: prefer the
  /// typed playback / playlist methods (`play`, `pause`, `seek`,
  /// `add`, `jump`, …) when they cover your use case.
  ///
  /// Throws [StateError] if the player has been disposed, or
  /// [MpvException] if mpv rejects the command (unknown command,
  /// invalid argument, etc.). A successful return guarantees mpv
  /// accepted the command; the actual side-effect on playback state
  /// is observed asynchronously via [Player.stream].
  Future<void> sendRawCommand(List<String> args) async {
    _checkNotDisposed();
    await _ready;
    // Symmetric guard with `setRawProperty('af', ...)`: mpv exposes
    // `af` and `af-command` as commands that mutate the audio chain
    // incrementally — bypassing the typed `AudioEffects` bundle and
    // desynchronizing `state.audioEffects`. The bundle is the single
    // writer of mpv's `af` property; raw incremental mutation goes
    // through `AudioEffects.custom` instead.
    if (args.isNotEmpty && (args.first == 'af' || args.first == 'af-command')) {
      throw ArgumentError.value(
        args.first,
        'args[0]',
        'Command `${args.first}` is owned by the typed AudioEffects bundle. '
            'Use Player.setAudioEffects / updateAudioEffects, and pass '
            'experimental or expression-based filters via AudioEffects.custom.',
      );
    }
    final rc = _command(args);
    if (rc < 0) {
      throw MpvException(
        name: args.isEmpty ? '<empty>' : args.first,
        code: rc,
        message: _errorString(rc),
      );
    }
  }

  /// Changes the engine log verbosity at runtime (the initial value comes
  /// from [PlayerConfiguration.logLevel]).
  Future<void> setLogLevel(LogLevel level) async {
    _checkNotDisposed();
    await _ready;
    // `mpv_request_log_messages` is thread-safe and operates on the shared
    // client handle the same way the main-thread getRawProperty path does,
    // so there's no need to round-trip through the event isolate.
    // [LogLevel.off] already maps to mpv's `no`.
    using(
      (arena) => _lib.mpvRequestLogMessages(
        _handle,
        level.mpvValue.toNativeUtf8(allocator: arena),
      ),
    );
  }
}
