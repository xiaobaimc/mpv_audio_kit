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

part 'isolate_events.dart';
part 'isolate_messages.dart';

// ── Tunables ─────────────────────────────────────────────────────────────────

/// Throttle window for the high-frequency `time-pos` property. mpv emits a
/// position update on every output sample buffer, which is roughly the audio
/// device's tick (~10ms on most outputs) — way more than any UI needs.
/// ~33ms ≈ 30Hz is comfortably inside human-perception territory for a
/// progress bar update and keeps the message bus uncluttered.
const int _kTimePosThrottleMs = 33;

/// Idle-mode timeout for `mpv_wait_event`.
///
/// When no events are pending the loop parks here.  The
/// `mpv_set_wakeup_callback` registered via [NativeCallable.listener]
/// fires on THIS isolate's event loop whenever mpv enqueues a new event,
/// which unblocks the wait immediately — so this value is the **worst-case**
/// idle floor, not the common-case latency.
///
/// Product: `0.05` s (50 ms) — five wakeups/sec is imperceptible but keeps
/// the stop-flag check alive.  Debug: `0.05` s for snappy Hot Restart.
/// Must stay finite — an infinite timeout reintroduces the macOS
/// Dock-Quit / Hot-Restart hang (dart-lang/sdk#46680).
const double _kIdleWakeupSeconds = 0.05;

/// Maximum time [MpvEventIsolate.stop] waits for the background isolate
/// to finish unwinding after `MPV_EVENT_SHUTDOWN`. The loop's natural
/// exit is fast on every supported platform; this bound caps the worst
/// case (e.g. a stalled syscall in libmpv) before the caller proceeds
/// with `mpv_terminate_destroy`.
const Duration _kIsolateExitTimeout = Duration(seconds: 2);

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

  // Per-isolate deduplication state — not shared across Player instances.
  final lastValues = <String, dynamic>{};
  final lastTimestamps = <String, int>{};

  // Keep the NativeCallable alive to prevent garbage collection while
  // registered with mpv. Must be closed before mpv_terminate_destroy.
  NativeCallable<Void Function(Pointer<Void>)>? wakeupCallable;

  fromMain.listen((message) {
    if (message is _InitMessage) {
      toMain = message.toMain;
      final wakeupCounter = message.wakeupCounterAddress != null
          ? Pointer<Int64>.fromAddress(message.wakeupCounterAddress!)
          : null;
      final stopFlag = Pointer<Int32>.fromAddress(message.stopFlagAddress);
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

        // Register a wakeup callback via NativeCallable so mpv can
        // signal this isolate when events are available.  The callback
        // fires on THIS isolate's event loop (NativeCallable.listener),
        // which unblocks any mpv_wait_event parked in a short timeout.
        // This is the event-driven equivalent of polling: instead of
        // waking on a fixed interval, we wake exactly when mpv has work.
        if (wakeupCounter != null) {
          wakeupCallable = NativeCallable.listener((Pointer<Void> _) {
            wakeupCounter.value++;
          });
          lib!.mpvSetWakeupCallback(
            h,
            wakeupCallable!.nativeFunction.cast(),
            nullptr.cast(),
          );
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
        stopFlag,
        lastValues,
        lastTimestamps,
        wakeupCounter,
      );
      // Tear down the wakeup callback before destroying the handle so
      // mpv never invokes a deleted trampoline.
      if (wakeupCallable != null) {
        lib!.mpvSetWakeupCallback(
          handle!,
          nullptr.cast(),
          nullptr.cast(),
        );
        wakeupCallable!.close();
        wakeupCallable = null;
      }
      // Drop the last live ReceivePort so the VM tears the isolate
      // down naturally — this runs the per-isolate finalizers that
      // release libmpv-side state loaded via `MpvLibrary.open`.
      // `Isolate.exit()` would skip those finalizers and leave
      // subsequent Player creations observing degraded process state.
      fromMain.close();
    }
  });
}

void _runEventLoop(
  mpv.MpvLibrary lib,
  Pointer<mpv.MpvHandle> handle,
  SendPort toMain,
  Pointer<Int32> stopFlag,
  Map<String, dynamic> lastValues,
  Map<String, int> lastTimestamps,
  Pointer<Int64>? wakeupCounter,
) {
  while (stopFlag.value == 0) {
    // Test-only telemetry; null in production.
    if (wakeupCounter != null) {
      wakeupCounter.value = wakeupCounter.value + 1;
    }

    // Event-driven: drain all pending events non-blocking first, then
    // park in a SHORT timeout.  The mpv_set_wakeup_callback registered
    // above will fire on this isolate's event loop whenever new events
    // arrive, causing mpv_wait_event to return immediately.
    //
    // Using 0 (pure non-blocking) followed by a bounded sleep would
    // busy-spin when idle.  A single mpv_wait_event with a short
    // timeout avoids that while keeping worst-case latency at
    // _kIdleWakeupMs instead of the old 1-second floor.
    final event = lib.mpvWaitEvent(handle, _kIdleWakeupSeconds);

    // Re-read the flag the instant the wait returns. `requestStop` sets the
    // flag THEN calls `mpv_wakeup`, so a wakeup-driven return lands here with
    // the flag already `1` — this is the lost-wakeup-safe exit edge, and it
    // does not depend on mpv emitting `MPV_EVENT_SHUTDOWN`.
    if (stopFlag.value != 0) {
      break;
    }

    final id = event.ref.eventId;

    // MPV_EVENT_NONE on a positive-timeout expiry, or on an `mpv_wakeup` with
    // no pending event — nothing to dispatch, loop and re-check the flag.
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
  // Native stop flag (Int32): the main isolate sets it to 1 in [requestStop],
  // the worker reads it every loop turn. Allocated in [start], freed in [stop]
  // ONLY on confirmed worker exit, so no parked reader survives the free.
  Pointer<Int32>? _stopFlag;
  // Non-broadcast: a single subscriber and buffering for events that
  // arrive between isolate-start and the main-side listen registration.
  // Using a broadcast controller dropped the initial PROPERTY_CHANGE
  // burst (mpv emits one per `mpv_observe_property` call right after
  // the isolate begins polling — ~70 properties), leaving downstream
  // state partially populated.
  final _events = StreamController<MpvIsolateEvent>();

  /// The post-init event stream; single-subscription with buffering (see
  /// the [_events] field for why the initial burst must not be dropped).
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

    _stopFlag = calloc<Int32>()..value = 0;

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

    _toIsolate!.send(
      _InitMessage(
        fromIsolate.sendPort,
        libraryPath: libraryPath,
        preInitOptions: preInitOptions,
        postInitOptions: postInitOptions,
        observes: observes,
        logLevel: logLevel,
        wakeupCounterAddress: wakeupCounterAddress,
        stopFlagAddress: _stopFlag!.address,
      ),
    );

    return initDone.future;
  }

  /// Unblocks the event loop deterministically. Call from the main isolate in
  /// `Player.dispose()` AFTER `mpv_command(['quit'])`, immediately before
  /// [stop].
  ///
  /// Order is load-bearing: set the native stop flag FIRST (publish the
  /// intent), THEN `mpv_wakeup`. A parked `mpv_wait_event` returns at once
  /// with `MPV_EVENT_NONE`; the worker re-reads the flag and breaks. `mpv_wakeup`
  /// is thread-safe (libmpv) and guarantees no lost wakeups, so this works even
  /// if `quit` was dropped (`MPV_ERROR_EVENT_QUEUE_FULL`) or `MPV_EVENT_SHUTDOWN`
  /// is delayed by a stalled hook. Idempotent and null-safe.
  void requestStop(mpv.MpvLibrary lib, Pointer<mpv.MpvHandle> handle) {
    _stopFlag?.value = 1;
    lib.mpvWakeup(handle);
  }

  /// Awaits the worker isolate's ACTUAL termination.
  ///
  /// Returns `true` iff the exit was confirmed within [_kIsolateExitTimeout].
  /// On `false` the worker is NOT proven to have left `mpv_wait_event`, so the
  /// caller MUST NOT `mpv_terminate_destroy` the handle — freeing it while the
  /// isolate is still inside the syscall reads freed memory and SIGSEGVs at
  /// teardown. [Isolate.kill] is never used for the same reason (killing
  /// mid-FFI to libmpv is a non-deterministic crash).
  ///
  /// The native stop flag is freed ONLY on confirmed exit, when no parked
  /// reader can survive the free; on the timeout branch it is intentionally
  /// leaked (4 bytes, bounded by live Player count, reclaimed at process exit).
  Future<bool> stop() async {
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
      _freeStopFlag();
      return true;
    }

    _isolate = null;
    _toIsolate = null;
    _exitPort = null;

    // The exit listener was armed in `start()` before the isolate could
    // possibly tear down. The 2 s timeout is a safety net for a pathologically
    // stuck libmpv — clean exits land in single-digit ms via `mpv_wakeup`.
    try {
      await exitPort.first.timeout(_kIsolateExitTimeout);
      _freeStopFlag();
      return true;
    } on TimeoutException {
      return false;
    } finally {
      exitPort.close();
    }
  }

  void _freeStopFlag() {
    final flag = _stopFlag;
    if (flag != null) {
      calloc.free(flag);
      _stopFlag = null;
    }
  }
}
