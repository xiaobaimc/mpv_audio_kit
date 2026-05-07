// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../mpv_bindings.dart';
import 'debug_log.dart';
import 'orphan_handle_tracker.dart';

/// Native-resource bag attached to a `Player` via [Finalizer].
/// Carries the `mpv_handle*` plus the `MpvLibrary` needed to send a
/// cooperative `quit`. `Player.dispose()` flips [disposed] so a
/// late-firing finalizer becomes a no-op.
@internal
class PlayerNativeResources {
  PlayerNativeResources(this.lib, this.handle);

  final MpvLibrary lib;
  final Pointer<MpvHandle> handle;
  bool disposed = false;
}

/// Safety net for consumers that drop a `Player` without calling
/// `dispose()` — fires on GC of the `Player` instance.
///
/// The finalizer issues a cooperative `quit` via `mpv_command_string`
/// rather than calling `mpv_terminate_destroy` directly. The latter
/// would race the still-running event isolate (blocked inside
/// `mpv_wait_event` on the same handle) and crash at process
/// teardown. The cooperative quit lets mpv fire `MPV_EVENT_SHUTDOWN`
/// and the isolate unwinds on its own; final handle release is left
/// to the OS at process exit.
///
/// Hot-Restart is handled separately by [OrphanHandleTracker] — Dart
/// finalizers don't fire when the VM is replaced.
@internal
final Finalizer<PlayerNativeResources> playerFinalizer =
    Finalizer<PlayerNativeResources>(finalizePlayerForTesting);

/// Internal entry point for the finalizer logic. Exposed (without
/// underscore prefix) so unit tests can drive it with a spy
/// [MpvLibrary] without forcing a real GC. Production code MUST NOT
/// call this directly — use `Player.dispose()` instead.
@visibleForTesting
void finalizePlayerForTesting(PlayerNativeResources resources) {
  if (resources.disposed) return;
  try {
    debugLog(
      'mpv_audio_kit: Player GC\'d without dispose() '
      '(handle=${resources.handle.address}). Sending cooperative quit. '
      'Prefer `await player.dispose()` to avoid this safety net.',
    );
    OrphanHandleTracker.instance.remove(resources.handle);
    final cmd = 'quit'.toNativeUtf8();
    try {
      resources.lib.mpvCommandString(resources.handle, cmd);
    } finally {
      calloc.free(cmd);
    }
  } catch (e) {
    debugLog('mpv_audio_kit: finalizer cleanup failed: $e');
  } finally {
    resources.disposed = true;
  }
}
