// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
part of '../player.dart';

/// Hook setters: register / continue mpv hooks. Hooks let you intercept
/// mpv's file-loading pipeline to lazily resolve a URL, inject per-file
/// HTTP headers, or redirect to a different source.
///
/// Usage pattern:
/// ```dart
/// player.registerHook(Hook.load);
/// player.stream.hook.listen((event) async {
///   if (event.hook == Hook.load) {
///     final url = await player.getRawProperty('stream-open-filename') ?? '';
///     // Optionally redirect the URL:
///     await player.setRawProperty('stream-open-filename', newUrl);
///     // Optionally set per-file HTTP headers:
///     await player.setRawProperty(
///         'file-local-options/http-header-fields', 'X-Token: abc');
///   }
///   player.continueHook(event.id); // must always be called
/// });
/// ```
mixin _HooksModule on _PlayerBase {
  /// Registers an mpv hook for [hook] with optional [priority].
  ///
  /// Hook events are delivered via [PlayerStream.hook]. Call
  /// [continueHook] with the event's [MpvHookEvent.id] when processing
  /// is complete — until then, mpv suspends the operation guarded by
  /// this hook.
  ///
  /// If [timeout] is provided, the library automatically calls
  /// [continueHook] after the given duration if you haven't called it
  /// yet. Prevents mpv from stalling indefinitely on unhandled
  /// exceptions in the listener.
  ///
  /// Idempotent per [hook]: calling [registerHook] more than once for
  /// the same hook on the same [Player] only updates the optional
  /// [timeout]; the underlying mpv registration happens once. mpv
  /// allows multiple registrations per name but its shutdown path can
  /// stall when several events for the same hook are still active at
  /// `quit` — duplicates are collapsed here to avoid that race.
  ///
  /// See [Hook] for the full set of available phases. Higher
  /// [priority] values run earlier; the default (0) is fine for most
  /// uses.
  Future<void> registerHook(Hook hook,
      {int priority = 0, Duration? timeout,}) async {
    await _gate();
    final name = hook.mpvValue;
    if (timeout != null) _hookTimeouts[name] = timeout;
    if (_registeredHookNames.contains(name)) return;
    _registeredHookNames.add(name);
    // `mpv_hook_add` locks the core (it waits for the playloop to reach a
    // dispatch point), so on the main isolate it would stall behind a busy
    // audio-output init. There is no command/async equivalent in the client
    // API — run it in a throwaway isolate, where waiting is harmless. The
    // registration targets the shared client handle, so hook events still
    // arrive on the player's event isolate.
    final handleAddress = _handle.address;
    final libraryPath = MpvAudioKit.libraryPath;
    // Track the run so dispose() can await it before freeing the handle —
    // mpv_hook_add does `lock_core(ctx)` on the shared core, and a busy
    // playloop can hold it long enough for a concurrent dispose to reach
    // mpv_terminate_destroy first (use-after-free on the freed MPContext).
    final run = Isolate.run(() {
      final lib = MpvLibrary.open(libraryPath);
      using((arena) {
        lib.mpvHookAdd(
          Pointer<MpvHandle>.fromAddress(handleAddress),
          0,
          name.toNativeUtf8(allocator: arena),
          priority,
        );
      });
    });
    _pendingHookAdds.add(run);
    try {
      await run;
    } finally {
      _pendingHookAdds.remove(run);
    }
  }

  /// Signals mpv that hook processing for [id] is complete.
  ///
  /// Should be called exactly once per [MpvHookEvent] received on
  /// [PlayerStream.hook], even if your processing fails — otherwise mpv
  /// will stall indefinitely waiting for the hook to return.
  ///
  /// Idempotent on a per-id basis: a second [continueHook] call for the
  /// same id (a buggy double-dispatch in your code, or a manual continue
  /// racing the auto-timeout fallback) is dropped before reaching mpv.
  /// mpv's behaviour for an already-continued id is undefined across
  /// versions, so the active set is tracked internally.
  ///
  /// Calling with an invalid [id] (zero or negative — typo in a dispatch
  /// table) is also a no-op: a warning is logged on
  /// [PlayerStream.internalLog] and the FFI call is skipped.
  Future<void> continueHook(int id) async {
    await _gate();
    if (id <= 0) {
      _internalLog(
        'continueHook: ignored invalid hook id $id (must be a positive '
        'integer obtained from MpvHookEvent.id)',
        level: LogLevel.warn,
      );
      return;
    }
    if (!_activeHookIds.remove(id)) {
      // Already continued (manual + auto-timer race, or caller
      // double-dispatch). Drop silently — the first continue already
      // unblocked mpv.
      return;
    }
    _hookTimers.remove(id)?.cancel();
    // Safe on the main isolate even though `mpv_hook_continue` locks the
    // core: a live id in `_activeHookIds` means mpv is parked at the hook's
    // dispatch point waiting for exactly this call, so the lock is granted
    // immediately — the playloop cannot simultaneously be busy elsewhere.
    _lib.mpvHookContinue(_handle, id);
  }
}
