// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../player.dart';

/// Inbound event pump: turns each [MpvIsolateEvent] forwarded from the event
/// isolate into state mutations and stream emits, routes property changes to
/// the registry (falling back to the custom JSON / derived handlers), and
/// owns the FILE_LOADED-time polls (position, chapters, embedded cover).
/// `_handleEvent` is the abstract member bring-up wires as the isolate's
/// `onEvent`; the rest are internal to this mixin.
mixin _DispatchModule on _PlayerBase {
  @override
  void _handleEvent(MpvIsolateEvent event) {
    // Single fence for every controller add() in this method — dispose()
    // flips `_disposed` before awaiting `_eventSub.cancel()`, so passing
    // this check guarantees every downstream add() lands on an open
    // controller without per-call isClosed checks.
    if (_disposed) return;
    // A throw from any branch below — most plausibly a malformed observed
    // NODE property reaching the one unguarded parser path (registry
    // dispatch) — must never escape this onData callback: the event
    // subscription registers no onError, so an escaped throw becomes an
    // unhandled async error (and under a guarded zone can escalate). Contain
    // and log it; one bad event is dropped, the stream keeps delivering.
    try {
      switch (event) {
        case MpvEventStartFile():
          // Latch "a file load has been attempted" HERE, not on FILE_LOADED:
          // START_FILE fires for every load attempt — including one that will
          // fail to open — so a failed first open() still arms the
          // idle-active intent reset (otherwise its intent would stick true
          // forever). START_FILE is always delivered AFTER the cold-start
          // idle-active burst (FIFO), so the latch still can't be tripped by
          // the startup burst.
          _hasLoadedFile = true;
          _updateLifecycle(buffering: true, completed: false);
        case MpvEventFileLoaded():
          // `state.playing` is driven by the `core-idle` observer; here we
          // only clear buffering/completed and trigger cover-art capture.
          _updateLifecycle(buffering: false, completed: false);
          _pollPosition();
          _pollChapterState();
          // Cover extraction is pure FFI over an mpv-owned buffer; a rare
          // malformed / oversized embedded picture (or an mpv buffer in an
          // unexpected state) must never abort the rest of file-load setup.
          // Above all it must NOT skip the waveform re-arm below: if it did,
          // one bad track would freeze the live waveform AND the now-playing
          // artwork for the whole session (both ride this single handler).
          try {
            _extractEmbeddedCover();
          } catch (e, st) {
            _internalLog(
              'Embedded cover extraction failed on file-load: $e\n$st',
              level: LogLevel.warn,
            );
          }
          // Re-arm the waveform ONLY on a genuine source change. mpv re-emits
          // FILE_LOADED on internal reloads (EDL / segment / gapless / track
          // reinit) for the same audio; resetting there would discard a
          // completed bulk envelope, force a full re-decode, and flash the meter
          // to empty. Key off the playlist entry `path` — stable across an
          // on_load hook that rewrites stream-open-filename but not `path`,
          // and distinct per track.
          if (_bringUpCompleted) {
            final src = _getPropStringSync('path');
            if (src != _lastWaveformSource) {
              _lastWaveformSource = src;
              _waveformPipeline.reset();
            }
          }
        case MpvEventPlaybackSeek():
          // No-op: a seek's landing is observed via PLAYBACK_RESTART
          // (`seekCompleted`); nothing needs the SEEK event itself.
          break;
        case MpvEventPlaybackRestart():
          _pollPosition();
          _seekCompletedCtrl.add(null);
        case MpvEndFileEvent(:final reason, :final error):
          final typedReason = MpvEndFileReason.fromValue(reason);
          _endFileCtrl.add(
            MpvFileEndedEvent(
              reason: typedReason,
              error: error,
            ),
          );
          if (error < 0) {
            _errorCtrl.add(
              MpvEndFileError(
                reason: typedReason,
                code: error,
                message: _errorString(error),
              ),
            );
          }
          final isEof = reason == MpvEndFileReason.eof.value;
          _updateLifecycle(playing: false, buffering: false, completed: isEof);
        case MpvEventShutdown():
          _updateLifecycle(playing: false, buffering: false);
        case MpvEventPropertyDouble(:final name, :final value):
          _dispatchProperty(name, value);
        case MpvEventPropertyInt(:final name, :final value):
          _dispatchProperty(name, value);
        case MpvEventPropertyString(:final name, :final value):
          _dispatchProperty(name, value);
        case MpvEventPropertyNode(:final name, :final value):
          _dispatchProperty(name, value);
        case MpvEventLog(:final prefix, :final level, :final text):
          final typedLevel = LogLevel.fromMpv(level);
          final entry =
              MpvLogEntry(prefix: prefix, level: typedLevel, text: text);
          _logCtrl.add(entry);
          if (typedLevel == LogLevel.error || typedLevel == LogLevel.fatal) {
            _errorCtrl.add(
              MpvLogError(
                prefix: prefix,
                level: typedLevel,
                text: text,
              ),
            );
          }
        case MpvEventHookFired(:final id, :final name):
          final hook = Hook.fromMpv(name);
          if (hook == null) {
            // Unknown hook name — likely a future mpv build added a new
            // phase. Auto-continue so mpv never stalls, log it on the
            // internal channel for diagnostics.
            _internalLog(
              'Received unknown hook "$name" (id=$id) — auto-continuing. '
              'Update the Hook enum if mpv has added a new lifecycle phase.',
              level: LogLevel.warn,
            );
            _lib.mpvHookContinue(_handle, id);
            return;
          }
          _activeHookIds.add(id);
          final timeout = _hookTimeouts[name];
          if (timeout != null) _startHookTimeout(id, name, timeout);
          _hookCtrl.add(MpvHookEvent(id, hook));
      }
    } catch (e, st) {
      _internalLog(
        'Unhandled error while handling $event: $e\n$st',
        level: LogLevel.warn,
      );
    }
  }

  /// Test-only entry point that exercises the same dispatch pipeline as
  /// the real event isolate. Lets integration tests force a property
  /// transition (e.g. `audio-output-state == failed`) without depending
  /// on the host AO actually reaching that state.
  @visibleForTesting
  void debugDispatchProperty(String name, dynamic raw) =>
      _dispatchProperty(name, raw);

  /// Routes a property-change to the registry first, then falls back to the
  /// custom handlers for properties whose update logic doesn't fit a simple
  /// (parser, reducer) pair (JSON parsing with player-side context, derived
  /// fields aggregating multiple mpv properties, etc.).
  void _dispatchProperty(String name, dynamic raw) {
    // `commit` assigns the reduced state to `_state` BEFORE the spec's
    // onChange fires, so a hook that reads + mutates `_state` (the
    // idle-active / eof-reached hooks settling the transport) builds on the
    // reduced state and isn't clobbered by a late assignment here.
    final next =
        _registry.dispatch(name, raw, _state, commit: (s) => _state = s);
    if (next != null) {
      return;
    }
    if (_registry.specFor(name) != null) {
      // Spec exists but value was deduplicated — nothing to do.
      return;
    }
    // Custom out-of-registry handlers for the few properties whose update
    // logic touches more than `(parse → reduce)` (player-side context like
    // `_mediaCache`, `_state.playlist`, `_state.cache.secs`, or the
    // two-property aggregation behind `loop`).
    switch (name) {
      case 'loop-file':
      case 'loop-playlist':
        _updateLoopFromMpv(name, raw as String);
      case 'playlist':
        _updatePlaylistFromNode(raw);
      case 'audio-device':
        _updateActiveAudioDevice(raw as String);
      case 'audio-device-list':
        _updateDevicesFromNode(raw);
      case 'metadata':
        _updateMetadataFromNode(raw);
      case 'demuxer-cache-state':
        _updateBufferingPercentageFromNode(raw);
    }
  }

  // --- Custom property handlers (JSON / derived) ---

  void _updateLoopFromMpv(String name, String value) {
    final next = deriveLoop(name, value, _state.loop);
    if (next == null) return;
    _updateField(
      (s) => s.copyWith(loop: next),
      _loop,
      next,
    );
  }

  void _updatePlaylistFromNode(dynamic raw) {
    try {
      final playlist = parsePlaylistNode(
        raw: raw,
        mediaCache: _mediaCache,
        previous: _state.playlist,
      );
      _updateField((s) => s.copyWith(playlist: playlist), _playlist, playlist);
    } catch (e) {
      _internalLog('Failed to parse playlist: $e', level: LogLevel.warn);
    }
  }

  @override
  void _updateActiveAudioDevice(String name) {
    // mpv only echoes the device name back on `audio-device`. Recover
    // the proper description by looking it up in the parsed
    // `audio-device-list` (state.audioDevices). Falls back to the name
    // on cache miss — typical at boot, before the list arrives.
    final list = _state.audioDevices;
    String description = name;
    for (final d in list) {
      if (d.name == name) {
        description = d.description;
        break;
      }
    }
    final device = Device(name: name, description: description);
    _updateField(
      (s) => s.copyWith(audioDevice: device),
      _reactives.audioDevice,
      device,
    );
  }

  void _updateDevicesFromNode(dynamic raw) {
    try {
      final devices = parseDeviceListNode(raw);
      _updateField(
        (s) => s.copyWith(audioDevices: devices),
        _audioDevices,
        devices,
      );
    } catch (e) {
      _internalLog('Failed to parse audio devices: $e', level: LogLevel.warn);
    }
  }

  void _updateMetadataFromNode(dynamic raw) {
    try {
      final metadata = parseMetadataNode(raw);
      if (metadata == null) return;
      _updateField((s) => s.copyWith(metadata: metadata), _metadata, metadata);
    } catch (e) {
      _internalLog('Failed to parse metadata: $e', level: LogLevel.warn);
    }
  }

  void _updateBufferingPercentageFromNode(dynamic raw) {
    try {
      final pct = parseDemuxerCacheStateNode(raw, _state.cache.secs);
      _updateField(
        (s) => s.copyWith(bufferingPercentage: pct),
        _bufferingPercentage,
        pct,
      );
      final cacheState = parseDemuxerCacheStateFull(raw);
      _updateField(
        (s) => s.copyWith(demuxerCacheState: cacheState),
        _demuxerCacheState,
        cacheState,
      );
    } catch (e) {
      _internalLog('Failed to parse cache state: $e', level: LogLevel.warn);
    }
  }

  // --- Misc helpers ---

  void _pollPosition() {
    if (_disposed) return;
    using((arena) {
      final n = 'time-pos'.toNativeUtf8(allocator: arena);
      final buf = arena<Double>();
      final rc = _lib.mpvGetProperty(
        _handle,
        n,
        MpvFormat.mpvFormatDouble,
        buf.cast(),
      );
      if (rc == MpvError.mpvErrorSuccess) {
        final pos = Duration(microseconds: (buf.value * 1e6).round());
        _updateField(
          (s) => s.copyWith(position: pos),
          _reactives.position,
          pos,
        );
      }
    });
  }

  /// Force-refreshes [PlayerState.chapters] and
  /// [PlayerState.currentChapter] by reading the underlying mpv
  /// properties directly. mpv's observer queue dedupes on
  /// `equal_mpv_value` (see `player/client.c::send_client_property_changes`),
  /// so two consecutive tracks with structurally-equal `chapter-list`
  /// (e.g. an audiobook where consecutive parts share the same chapter
  /// pattern) would skip the PROPERTY_CHANGE event and strand the
  /// wrapper at whatever the previous file left behind. Polling on
  /// FILE_LOADED bypasses the dedup so the wrapper always carries the
  /// truth for the current file.
  void _pollChapterState() {
    if (_disposed) return;
    // chapter index — INT64 scalar.
    using((arena) {
      final n = 'chapter'.toNativeUtf8(allocator: arena);
      final buf = arena<Int64>();
      final rc =
          _lib.mpvGetProperty(_handle, n, MpvFormat.mpvFormatInt64, buf.cast());
      if (rc == MpvError.mpvErrorSuccess) {
        // mpv exposes -1 / -2 etc. as "no chapter active"; surface as null.
        final idx = buf.value < 0 ? null : buf.value.toInt();
        _updateField(
          (s) => s.copyWith(currentChapter: idx),
          _reactives.currentChapter,
          idx,
        );
      }
    });
    // chapter-list — NODE_ARRAY. Allocate, read, decode, dispatch
    // through the registry (re-using the parser), free the node tree.
    using((arena) {
      final n = 'chapter-list'.toNativeUtf8(allocator: arena);
      final nodePtr = arena<MpvNode>();
      final rc = _lib.mpvGetProperty(
        _handle,
        n,
        MpvFormat.mpvFormatNode,
        nodePtr.cast(),
      );
      if (rc == MpvError.mpvErrorSuccess) {
        final decoded = decodeMpvNode(nodePtr.ref);
        try {
          _dispatchProperty('chapter-list', decoded);
        } finally {
          _lib.mpvFreeNodeContents(nodePtr);
        }
      }
    });
  }

  void _extractEmbeddedCover() {
    if (_disposed) return;
    // Emit unconditionally — `null` signals "no cover on the new
    // file" so subscribers can clear stale artwork on track changes.
    final cover = CoverArtExtractor.capture(_lib, _handle);
    _state = _state.copyWith(coverArt: cover);
    _coverArtCtrl.add(cover);
  }

  /// Synchronous string-property read for use inside the event handler (the
  /// public [getRawProperty] is async). Returns null if the handle is gone or
  /// the property is unavailable.
  String? _getPropStringSync(String name) {
    if (_handle == nullptr) return null;
    return using<String?>((arena) {
      final n = name.toNativeUtf8(allocator: arena);
      final ptr = _lib.mpvGetPropertyString(_handle, n);
      if (ptr == nullptr) return null;
      final s = ptr.cast<Utf8>().toDartString();
      _lib.mpvFree(ptr.cast());
      return s;
    });
  }
}
