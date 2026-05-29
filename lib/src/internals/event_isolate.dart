// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../mpv_bindings.dart' as mpv;

// ── Tunables ─────────────────────────────────────────────────────────────────

/// Throttle window for the high-frequency `time-pos` property. mpv emits a
/// position update on every output sample buffer, which is roughly the audio
/// device's tick (~10ms on most outputs) — way more than any UI needs.
/// ~33ms ≈ 30Hz is comfortably inside human-perception territory for a
/// progress bar update and keeps the message bus uncluttered.
const int _kTimePosThrottleMs = 33;

/// `mpv_wait_event` timeout.
///
/// Release / profile: `-1` blocks until the next mpv event, so there
/// are zero wake-ups during idle playback. Debug: `0.1` (100 ms) — the
/// Dart VM cannot interrupt an isolate stuck in a blocking FFI call
/// (dart-lang/sdk#46680), so Hot Restart would hang under `-1` while a
/// `Player` is alive; the timeout gives the kill request a checkpoint.
const double _kWaitEventTimeoutSeconds =
    bool.fromEnvironment('dart.vm.product') ? -1.0 : 0.1;

/// Maximum time [MpvEventIsolate.stop] waits for the background isolate
/// to finish unwinding after `MPV_EVENT_SHUTDOWN`. The loop's natural
/// exit is fast on every supported platform; this bound caps the worst
/// case (e.g. a stalled syscall in libmpv) before the caller proceeds
/// with `mpv_terminate_destroy`.
const Duration _kIsolateExitTimeout = Duration(seconds: 2);

// ── Messages: main → isolate ─────────────────────────────────────────────────

/// Carries the full "init recipe" so the isolate can run the heavy
/// FFI sequence (`mpv_create` → pre-init opts → `mpv_initialize` →
/// post-init opts → `mpv_observe_property` × N) off the main thread.
class _InitMessage {
  final SendPort toMain;
  final String? libraryPath;
  final Map<String, String> preInitOptions;
  final Map<String, String> postInitOptions;
  final List<MpvObserveSpec> observes;

  /// Optional `mpv_request_log_messages` level, applied between
  /// `mpv_create` and `mpv_initialize`.
  final String? logLevel;

  /// Test-only: address of an `Int64` cell incremented once per
  /// `mpv_wait_event` return, so tests can assert the loop doesn't
  /// busy-poll. `null` in production.
  final int? wakeupCounterAddress;

  _InitMessage(
    this.toMain, {
    this.libraryPath,
    required this.preInitOptions,
    required this.postInitOptions,
    required this.observes,
    this.logLevel,
    this.wakeupCounterAddress,
  });
}

/// Single property to register via `mpv_observe_property` from the
/// isolate. [replyId] is opaque user data; the dispatcher matches by
/// name on the receive side.
class MpvObserveSpec {
  /// mpv property name to observe (e.g. `time-pos`, `pause`).
  final String name;

  /// The `MPV_FORMAT_*` constant the property's value is delivered in.
  final int format;

  /// Opaque user-data tag echoed back on each property change; the
  /// main-side dispatcher matches incoming changes by [name], not this.
  final int replyId;

  /// Describes a single property to register via `mpv_observe_property`.
  const MpvObserveSpec(this.name, this.format, this.replyId);
}

/// Tells the event loop isolate to exit cleanly.
class _ShutdownMessage {}

// ── Messages: isolate → main (init handshake only) ───────────────────────────

/// Init succeeded; carries the live `mpv_handle*` address so the main
/// isolate can wrap it as a `Pointer<MpvHandle>`.
class _InitDone {
  final int handleAddress;
  _InitDone(this.handleAddress);
}

/// Init failed somewhere between `mpv_create` and the final observe.
class _InitFailed {
  final String message;
  _InitFailed(this.message);
}

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

// ── Isolate entry point ───────────────────────────────────────────────────────

void _applyOptionStrings(
  mpv.MpvLibrary lib,
  Pointer<mpv.MpvHandle> handle,
  Map<String, String> opts,
) {
  for (final entry in opts.entries) {
    using((arena) {
      lib.mpvSetOptionString(
        handle,
        entry.key.toNativeUtf8(allocator: arena),
        entry.value.toNativeUtf8(allocator: arena),
      );
    });
  }
}

void _applyPropertyStrings(
  mpv.MpvLibrary lib,
  Pointer<mpv.MpvHandle> handle,
  Map<String, String> props,
) {
  for (final entry in props.entries) {
    using((arena) {
      lib.mpvSetPropertyString(
        handle,
        entry.key.toNativeUtf8(allocator: arena),
        entry.value.toNativeUtf8(allocator: arena),
      );
    });
  }
}

void _applyObserves(
  mpv.MpvLibrary lib,
  Pointer<mpv.MpvHandle> handle,
  List<MpvObserveSpec> observes,
) {
  for (final spec in observes) {
    using((arena) {
      lib.mpvObserveProperty(
        handle,
        spec.replyId,
        spec.name.toNativeUtf8(allocator: arena),
        spec.format,
      );
    });
  }
}

void _isolateEntry(SendPort initialReplyPort) {
  final fromMain = ReceivePort();
  initialReplyPort.send(fromMain.sendPort);

  SendPort? toMain;
  Pointer<mpv.MpvHandle>? handle;
  mpv.MpvLibrary? lib;
  bool running = true;

  // Per-isolate deduplication state — not shared across Player instances.
  final lastValues = <String, dynamic>{};
  final lastTimestamps = <String, int>{};

  fromMain.listen((message) {
    if (message is _InitMessage) {
      toMain = message.toMain;
      final wakeupCounter = message.wakeupCounterAddress != null
          ? Pointer<Int64>.fromAddress(message.wakeupCounterAddress!)
          : null;
      try {
        // The heavy FFI sequence runs here — off the main isolate so
        // the host UI keeps rendering during cold start.
        lib = mpv.MpvLibrary.open(message.libraryPath);
        final h = lib!.mpvCreate();
        if (h == nullptr) {
          toMain!.send(_InitFailed('mpv_create() returned NULL'));
          fromMain.close();
          return;
        }
        handle = h;
        _applyOptionStrings(lib!, h, message.preInitOptions);
        if (message.logLevel != null) {
          using((arena) {
            lib!.mpvRequestLogMessages(
              h,
              message.logLevel!.toNativeUtf8(allocator: arena),
            );
          });
        }
        final rc = lib!.mpvInitialize(h);
        if (rc < 0) {
          lib!.mpvTerminateDestroy(h);
          toMain!.send(_InitFailed('mpv_initialize() failed: rc=$rc'));
          fromMain.close();
          return;
        }
        _applyPropertyStrings(lib!, h, message.postInitOptions);
        _applyObserves(lib!, h, message.observes);
        toMain!.send(_InitDone(h.address));
      } catch (e, st) {
        toMain!.send(_InitFailed('init crashed: $e\n$st'));
        fromMain.close();
        return;
      }
      // Blocking call — returns when `_runEventLoop` breaks out of
      // its loop on MPV_EVENT_SHUTDOWN (sent by mpv after the main
      // isolate's `quit` command in dispose()).
      _runEventLoop(
        lib!,
        handle!,
        toMain!,
        () => running,
        lastValues,
        lastTimestamps,
        wakeupCounter,
      );
      // Drop the last live ReceivePort so the VM tears the isolate
      // down naturally — this runs the per-isolate finalizers that
      // release libmpv-side state loaded via `MpvLibrary.open`.
      // `Isolate.exit()` would skip those finalizers and leave
      // subsequent Player creations observing degraded process state.
      fromMain.close();
    } else if (message is _ShutdownMessage) {
      // Defensive: only reachable if `_InitMessage` never arrived
      // (race during isolate spawn). The flag-based exit on
      // `_runEventLoop` is the steady-state path.
      running = false;
      fromMain.close();
    }
  });
}

void _runEventLoop(
  mpv.MpvLibrary lib,
  Pointer<mpv.MpvHandle> handle,
  SendPort toMain,
  bool Function() isRunning,
  Map<String, dynamic> lastValues,
  Map<String, int> lastTimestamps,
  Pointer<Int64>? wakeupCounter,
) {
  while (isRunning()) {
    // Test-only telemetry; null in production.
    if (wakeupCounter != null) {
      wakeupCounter.value = wakeupCounter.value + 1;
    }
    final event = lib.mpvWaitEvent(handle, _kWaitEventTimeoutSeconds);
    final id = event.ref.eventId;

    // With timeout < 0, MPV_EVENT_NONE is unreachable in steady state
    // (mpv only returns `none` on positive-timeout expiry). Defensive
    // continue for spurious wakeups.
    if (id == mpv.MpvEventId.mpvEventNone) {
      continue;
    }

    _dispatchEvent(lib, handle, toMain, event, lastValues, lastTimestamps);

    if (id == mpv.MpvEventId.mpvEventShutdown) {
      break;
    }
  }
}

void _dispatchEvent(
  mpv.MpvLibrary lib,
  Pointer<mpv.MpvHandle> handle,
  SendPort toMain,
  Pointer<mpv.MpvEvent> event,
  Map<String, dynamic> lastValues,
  Map<String, int> lastTimestamps,
) {
  final id = event.ref.eventId;
  switch (id) {
    case mpv.MpvEventId.mpvEventShutdown:
      toMain.send(MpvEventShutdown());

    case mpv.MpvEventId.mpvEventStartFile:
      toMain.send(MpvEventStartFile());

    case mpv.MpvEventId.mpvEventFileLoaded:
      toMain.send(MpvEventFileLoaded());

    case mpv.MpvEventId.mpvEventEndFile:
      final ef = event.ref.data.cast<mpv.MpvEventEndFile>().ref;
      toMain.send(MpvEndFileEvent(ef.reason, ef.error));

    case mpv.MpvEventId.mpvEventPropertyChange:
      _dispatchProperty(
        lib,
        toMain,
        event.ref.data.cast<mpv.MpvEventProperty>().ref,
        lastValues,
        lastTimestamps,
      );

    case mpv.MpvEventId.mpvEventLogMessage:
      _dispatchLog(toMain, event.ref.data.cast<mpv.MpvEventLogMessage>().ref);

    case mpv.MpvEventId.mpvEventHook:
      final hook = event.ref.data.cast<mpv.MpvEventHook>().ref;
      final name = hook.name.cast<Utf8>().toDartString();
      toMain.send(MpvEventHookFired(hook.id, name));

    case mpv.MpvEventId.mpvEventSeek:
      toMain.send(MpvEventPlaybackSeek());

    case mpv.MpvEventId.mpvEventPlaybackRestart:
      // The main isolate polls time-pos synchronously in response, so
      // the new position lands on the stream before any throttled
      // time-pos event from the property observer.
      toMain.send(MpvEventPlaybackRestart());
  }
}

void _dispatchProperty(
  mpv.MpvLibrary lib,
  SendPort toMain,
  mpv.MpvEventProperty prop,
  Map<String, dynamic> lastValues,
  Map<String, int> lastTimestamps,
) {
  final name = prop.name.cast<Utf8>().toDartString();

  if (prop.format == mpv.MpvFormat.mpvFormatDouble && prop.data != nullptr) {
    final v = prop.data.cast<Double>().value;

    if (name == 'time-pos') {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = lastTimestamps[name] ?? 0;
      if (now - last < _kTimePosThrottleMs) {
        return;
      }
      lastTimestamps[name] = now;
    }

    if (lastValues[name] == v) {
      return;
    }
    lastValues[name] = v;

    toMain.send(MpvEventPropertyDouble(name, v));
    return;
  }

  if (prop.format == mpv.MpvFormat.mpvFormatFlag && prop.data != nullptr) {
    final v = prop.data.cast<Int32>().value;
    if (lastValues[name] == v) {
      return;
    }
    lastValues[name] = v;
    toMain.send(MpvEventPropertyInt(name, v));
    return;
  }

  if (prop.format == mpv.MpvFormat.mpvFormatInt64 && prop.data != nullptr) {
    final v = prop.data.cast<Int64>().value;
    if (lastValues[name] == v) {
      return;
    }
    lastValues[name] = v;
    toMain.send(MpvEventPropertyInt(name, v));
    return;
  }

  if (prop.format == mpv.MpvFormat.mpvFormatString && prop.data != nullptr) {
    final s = prop.data.cast<Pointer<Utf8>>().value.cast<Utf8>().toDartString();
    if (lastValues[name] == s) {
      return;
    }
    lastValues[name] = s;
    toMain.send(MpvEventPropertyString(name, s));
    return;
  }

  if (prop.format == mpv.MpvFormat.mpvFormatNode && prop.data != nullptr) {
    final decoded = decodeMpvNode(prop.data.cast<mpv.MpvNode>().ref);
    // Dedup against the JSON encoding of the decoded tree. Cheap, and
    // sufficient because mpv only emits Map/List/scalar shapes for the
    // properties the library observes. Falls through without dedup
    // when jsonEncode rejects the tree (no observed cases today).
    final key = _nodeDedupKey(decoded);
    if (key != null && lastValues[name] == key) {
      return;
    }
    if (key != null) lastValues[name] = key;
    toMain.send(MpvEventPropertyNode(name, decoded));
    return;
  }

  // Fallthrough: an unobserved format (NONE / OSD_STRING / top-level
  // BYTE_ARRAY) or `data == nullptr` ("property unavailable" mid-stream).
  // Drop silently — re-emitting a cached value would be wrong and a
  // sentinel would break downstream dedup.
}

void _dispatchLog(SendPort toMain, mpv.MpvEventLogMessage msg) {
  final prefix = msg.prefix.cast<Utf8>().toDartString();
  final level = msg.level.cast<Utf8>().toDartString();
  final text = msg.text.cast<Utf8>().toDartString().trimRight();
  toMain.send(MpvEventLog(prefix, level, text));
}

// ── Node decoding ─────────────────────────────────────────────────────────────

/// Recursively converts an mpv `mpv_node` C struct into a Dart-native tree.
///
/// Maps:
///   - `MPV_FORMAT_NONE`        → `null`
///   - `MPV_FORMAT_STRING`      → [String]
///   - `MPV_FORMAT_FLAG`        → [bool]
///   - `MPV_FORMAT_INT64`       → [int]
///   - `MPV_FORMAT_DOUBLE`      → [double]
///   - `MPV_FORMAT_NODE_ARRAY`  → `List<dynamic>` of recursively-decoded children
///   - `MPV_FORMAT_NODE_MAP`    → `Map<String, dynamic>` of recursively-decoded children
///   - `MPV_FORMAT_BYTE_ARRAY`  → [Uint8List] copied out of mpv-owned memory
///
/// The returned tree owns its memory: any data borrowed from mpv (strings,
/// byte arrays) is copied during decoding so the caller can safely dispose
/// of the source `mpv_node` via `mpv_free_node_contents` immediately after.
///
/// Exposed at top-level (rather than file-private) so unit tests can build
/// synthetic `mpv_node` trees and exercise the decoder without spinning up
/// a real player.
dynamic decodeMpvNode(mpv.MpvNode node) {
  switch (node.format) {
    case mpv.MpvFormat.mpvFormatString:
      return node.u.string.cast<Utf8>().toDartString();
    case mpv.MpvFormat.mpvFormatFlag:
      return node.u.flag != 0;
    case mpv.MpvFormat.mpvFormatInt64:
      return node.u.int64;
    case mpv.MpvFormat.mpvFormatDouble:
      return node.u.double_;
    case mpv.MpvFormat.mpvFormatNodeArray:
      final list = node.u.list.ref;
      return [
        for (var i = 0; i < list.num; i++) decodeMpvNode((list.values + i).ref),
      ];
    case mpv.MpvFormat.mpvFormatNodeMap:
      final list = node.u.list.ref;
      return <String, dynamic>{
        for (var i = 0; i < list.num; i++)
          (list.keys + i).value.cast<Utf8>().toDartString():
              decodeMpvNode((list.values + i).ref),
      };
    case mpv.MpvFormat.mpvFormatByteArray:
      final ba = node.u.ba.ref;
      // Copy out of mpv-owned memory before the caller frees the node.
      return Uint8List.fromList(ba.data.cast<Uint8>().asTypedList(ba.size));
    default:
      return null;
  }
}

String? _nodeDedupKey(dynamic decoded) {
  try {
    return jsonEncode(decoded);
  } catch (_) {
    return null;
  }
}

// ── Public bridge ─────────────────────────────────────────────────────────────

/// Manages the dedicated isolate that runs the mpv event loop.
///
/// The mpv API is thread-safe: the main isolate continues to call
/// [mpv_set_property], [mpv_command] etc. while this isolate blocks on
/// [mpv_wait_event], keeping the Flutter render thread free.
class MpvEventIsolate {
  Isolate? _isolate;
  SendPort? _toIsolate;
  ReceivePort? _fromIsolate;
  ReceivePort? _exitPort;
  // Non-broadcast: a single subscriber and buffering for events that
  // arrive between isolate-start and the main-side listen registration.
  // Using a broadcast controller dropped the initial PROPERTY_CHANGE
  // burst (mpv emits one per `mpv_observe_property` call right after
  // the isolate begins polling — ~70 properties), leaving downstream
  // state partially populated.
  final _events = StreamController<MpvIsolateEvent>();

  /// The post-init event stream. Single-subscription so the initial
  /// property-change burst (one per observed property, emitted the
  /// moment the isolate starts polling) is buffered until the main-side
  /// listener attaches, rather than dropped.
  Stream<MpvIsolateEvent> get events => _events.stream;

  /// Spawns the event isolate, runs the heavy mpv init recipe inside
  /// it, and resolves with the live `mpv_handle*` address. Heavy FFI
  /// (`mpv_create`, `mpv_initialize`, ~80 `mpv_observe_property`)
  /// never touches the main isolate, so the host UI stays responsive
  /// during cold start.
  ///
  /// The [onEvent] listener is wired BEFORE `_InitDone` is forwarded,
  /// eliminating the broadcast race that otherwise drops the initial
  /// property-change burst.
  ///
  /// [wakeupCounterAddress] is test-only.
  Future<int> start({
    String? libraryPath,
    void Function(MpvIsolateEvent)? onEvent,
    required Map<String, String> preInitOptions,
    required Map<String, String> postInitOptions,
    required List<MpvObserveSpec> observes,
    String? logLevel,
    int? wakeupCounterAddress,
  }) async {
    if (onEvent != null) _events.stream.listen(onEvent);

    final initPort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, initPort.sendPort);

    final completer = Completer<SendPort>();
    final sub = initPort.listen((msg) {
      if (msg is SendPort && !completer.isCompleted) {
        completer.complete(msg);
      }
    });
    _toIsolate = await completer.future;
    await sub.cancel();
    initPort.close();

    // Arm the exit listener BEFORE the isolate can possibly tear down.
    _exitPort = ReceivePort();
    _isolate!.addOnExitListener(_exitPort!.sendPort);

    final initDone = Completer<int>();
    final fromIsolate = ReceivePort();
    _fromIsolate = fromIsolate;
    fromIsolate.listen((msg) {
      if (msg is _InitDone) {
        if (!initDone.isCompleted) initDone.complete(msg.handleAddress);
        return;
      }
      if (msg is _InitFailed) {
        if (!initDone.isCompleted) {
          initDone.completeError(StateError(msg.message));
        }
        return;
      }
      // Drop messages that arrive after `stop()` has closed the
      // controller. Without this guard the queued message would throw
      // "Bad state: Cannot add new events after calling close" —
      // visible only when many Player instances are created and
      // disposed in rapid succession.
      if (msg is MpvIsolateEvent && !_events.isClosed) {
        _events.add(msg);
      }
    });

    _toIsolate!.send(_InitMessage(
      fromIsolate.sendPort,
      libraryPath: libraryPath,
      preInitOptions: preInitOptions,
      postInitOptions: postInitOptions,
      observes: observes,
      logLevel: logLevel,
      wakeupCounterAddress: wakeupCounterAddress,
    ),);

    return initDone.future;
  }

  /// Signals the isolate to exit and **awaits its actual termination**
  /// before returning.
  ///
  /// The player issues `mpv_command(['quit'])` immediately before
  /// calling [stop]; mpv processes that asynchronously and fires
  /// MPV_EVENT_SHUTDOWN, which lets the blocking [mpv_wait_event] in
  /// the isolate return so the loop unwinds naturally. The matching
  /// `mpv_terminate_destroy` runs only AFTER [stop] returns — calling
  /// it earlier would free the handle while the isolate is still
  /// inside `mpv_wait_event`.
  ///
  /// **Awaiting the isolate exit is load-bearing.** [Isolate.kill] is a
  /// cooperative request that returns before the isolate has actually
  /// finished. If `dispose()` returns while the isolate is still inside
  /// [mpv_wait_event] on a destroyed handle, the next syscall in the
  /// loop reads freed memory and produces a non-deterministic
  /// SIGSEGV at process teardown — visible across the whole test
  /// suite, not just the calling test.
  Future<void> stop() async {
    _fromIsolate?.close();
    _fromIsolate = null;
    // Fire-and-forget: closing the controller flushes any buffered
    // events to the (already-cancelled) subscriber; the load-bearing
    // wait is the isolate-exit await below, not this close.
    if (!_events.isClosed) unawaited(_events.close());

    final exitPort = _exitPort;
    final isolate = _isolate;
    if (isolate == null || exitPort == null) {
      _toIsolate = null;
      _exitPort = null;
      return;
    }

    // The main side has already sent `quit` to mpv (in dispose), so
    // `_runEventLoop` is on its way out via `MPV_EVENT_SHUTDOWN`. The
    // `_ShutdownMessage` here only covers the corner case where
    // `_InitMessage` never reached the isolate. `Isolate.kill` is
    // never used: killing mid-FFI to libmpv yields a non-deterministic
    // SIGSEGV at process teardown.
    _toIsolate?.send(_ShutdownMessage());
    _isolate = null;
    _toIsolate = null;
    _exitPort = null;

    // The exit listener was armed in `start()` before the isolate
    // could possibly tear down. The 2 s timeout is a safety net for a
    // pathologically stuck libmpv — clean exits land in single-digit ms.
    try {
      await exitPort.first.timeout(_kIsolateExitTimeout);
    } on TimeoutException {
      // Fall through.
    } finally {
      exitPort.close();
    }
  }
}
