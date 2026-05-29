// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

@TestOn('mac-os || linux || windows')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/src/internals/player_finalizer.dart';
import 'package:mpv_audio_kit/src/mpv_bindings.dart';

void main() {
  // M1 — when a Player is GC'd without dispose(), the finalizer must
  // NOT call mpv_terminate_destroy directly: the event isolate is
  // still inside mpv_wait_event on the same handle, and freeing the
  // handle out from under it is the documented SIGSEGV pattern (see
  // CLAUDE.md, "dispose teardown order"). Instead, the finalizer
  // sends a cooperative `quit` via mpv_command_string so mpv tears
  // itself down via the regular MPV_EVENT_SHUTDOWN path.
  //
  // We can't deterministically force a real GC in pure Dart. Instead
  // we drive the finalizer body directly via the
  // `finalizePlayerForTesting` seam and inspect the FFI calls a spy
  // library records.

  group('finalizer cooperative quit (M1)', () {
    test(
        'finalizer sends mpv_command_string("quit") and never calls '
        'mpv_terminate_destroy', () {
      final spy = _SpyMpvLibrary();
      final fakeHandle = Pointer<MpvHandle>.fromAddress(0xC0FFEE);
      final res = PlayerNativeResources(spy, fakeHandle);

      finalizePlayerForTesting(res);

      expect(spy.terminateDestroyCalls, 0,
          reason: 'finalizer must not race the live event isolate by '
              'calling mpv_terminate_destroy on the handle',);
      expect(spy.commandStringCalls, 1,
          reason: 'finalizer should issue exactly one cooperative quit',);
      expect(spy.lastCommand, equals('quit'),
          reason: 'cooperative quit must be the literal "quit" command',);
      expect(spy.lastHandle?.address, equals(fakeHandle.address));
      expect(res.disposed, isTrue,
          reason: 'PlayerNativeResources.disposed must flip so a late '
              'second finalize() (after the GC late-fires) is a no-op',);
    });

    test('finalizer is idempotent — already-disposed resource is a no-op', () {
      final spy = _SpyMpvLibrary();
      final res = PlayerNativeResources(
        spy,
        Pointer<MpvHandle>.fromAddress(0x1),
      )..disposed = true;

      finalizePlayerForTesting(res);

      expect(spy.commandStringCalls, 0);
      expect(spy.terminateDestroyCalls, 0);
    });

    test('exception inside the FFI call does not leak — disposed still set',
        () {
      final spy = _SpyMpvLibrary()..commandStringThrows = true;
      final res = PlayerNativeResources(
        spy,
        Pointer<MpvHandle>.fromAddress(0x2),
      );

      // Must not rethrow — the finalizer is the bottom of the stack
      // (no caller can recover from it), so it swallows and logs.
      finalizePlayerForTesting(res);

      expect(res.disposed, isTrue,
          reason: 'finalizer must mark the resource disposed even on '
              'cleanup failure, otherwise a retry on a stale handle '
              'could fire later',);
    });
  });
}

/// Stub [MpvLibrary] that records the two functions the finalizer is
/// allowed to touch. Constructed via the test-only
/// [MpvLibrary.uninitializedForTest] constructor; only the entries we
/// actually call are assigned, so any accidental call to a different
/// FFI function trips a [LateInitializationError] and surfaces
/// immediately as a test failure.
class _SpyMpvLibrary extends MpvLibrary {
  _SpyMpvLibrary() : super.uninitializedForTest() {
    mpvCommandString = (handle, cmd) {
      commandStringCalls++;
      lastHandle = handle;
      lastCommand = cmd.cast<Utf8>().toDartString();
      if (commandStringThrows) {
        throw StateError('simulated FFI failure');
      }
      return 0;
    };
    mpvTerminateDestroy = (handle) {
      terminateDestroyCalls++;
    };
  }

  int commandStringCalls = 0;
  int terminateDestroyCalls = 0;
  Pointer<MpvHandle>? lastHandle;
  String? lastCommand;
  bool commandStringThrows = false;
}
