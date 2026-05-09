// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../models/waveform_data.dart';
import '../mpv_bindings.dart';

/// Bulk waveform pipeline.
///
/// Polls mpv's `waveform-data` property at a low rate while a listener
/// is attached. The C-side worker decodes the whole track via libav on
/// a detached thread and bins min/max into a 2048-entry envelope. As
/// soon as the worker reports `state == "ready"`, the pipeline emits
/// the full envelope and stops the timer until the next track-change.
///
/// On track change the player calls [reset]: the pipeline drops the
/// current envelope, emits `null`, and rearms the polling timer to
/// catch the new file's worker.
@internal
class WaveformPipeline {
  WaveformPipeline({
    required MpvLibrary lib,
    required Pointer<MpvHandle> handle,
    Duration pollInterval = const Duration(milliseconds: 200),
  })  : _lib = lib,
        _handle = handle,
        _pollInterval = pollInterval {
    _ctrl = StreamController<WaveformData?>.broadcast(
      onListen: () {
        // Replay the last snapshot so a late subscriber sees the
        // current envelope immediately, not just future updates.
        if (_data != null) _ctrl.add(_data);
        _armTimer();
      },
      onCancel: () {
        if (_ctrl.hasListener) return;
        _pollTimer?.cancel();
        _pollTimer = null;
      },
    );
  }

  final MpvLibrary _lib;
  final Pointer<MpvHandle> _handle;
  final Duration _pollInterval;

  late final StreamController<WaveformData?> _ctrl;
  Timer? _pollTimer;

  // Once the worker reports "ready" we cache the envelope and stop
  // polling. [reset] clears it on track change.
  WaveformData? _data;
  bool _disposed = false;

  Stream<WaveformData?> get stream => _ctrl.stream;

  /// Drops the current envelope and emits `null` so renderers clear
  /// stale data on the track-change boundary. The polling timer is
  /// rearmed if anyone is listening, so the new file's worker is
  /// caught as soon as it reports "ready".
  void reset() {
    if (_disposed) return;
    _data = null;
    if (!_ctrl.isClosed) _ctrl.add(null);
    if (_ctrl.hasListener) _armTimer();
  }

  void _armTimer() {
    if (_disposed) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    // Kick one immediate poll so the first listener / a freshly-reset
    // pipeline doesn't have to wait a full tick to settle.
    _poll();
  }

  void _poll() {
    if (_disposed || _data != null) return;
    if (_handle == nullptr) return;

    final result = calloc<MpvNode>();
    try {
      final rc = using<int>((arena) {
        final name = 'waveform-data'.toNativeUtf8(allocator: arena);
        return _lib.mpvGetProperty(
          _handle,
          name,
          MpvFormat.mpvFormatNode,
          result.cast(),
        );
      });
      if (rc < 0) return;
      if (result.ref.format != MpvFormat.mpvFormatNodeMap) return;

      final list = result.ref.u.list.ref;
      String? state;
      var durationUs = 0;
      var binCount = 0;
      Float32List? bulkMin;
      Float32List? bulkMax;
      for (var i = 0; i < list.num; i++) {
        final keyPtr = list.keys[i];
        final key = keyPtr.cast<Utf8>().toDartString();
        final node = (list.values + i).ref;
        switch (key) {
          case 'state':
            if (node.format == MpvFormat.mpvFormatString) {
              state = node.u.string.cast<Utf8>().toDartString();
            }
          case 'duration_us':
            if (node.format == MpvFormat.mpvFormatInt64) {
              durationUs = node.u.int64;
            }
          case 'bins':
            if (node.format == MpvFormat.mpvFormatInt64) {
              binCount = node.u.int64;
            }
          case 'min':
            if (node.format == MpvFormat.mpvFormatByteArray) {
              final ba = node.u.ba.ref;
              if (ba.size > 0) {
                final n = ba.size ~/ 4;
                final src = ba.data.cast<Float>().asTypedList(n);
                bulkMin = Float32List(n)..setAll(0, src);
              }
            }
          case 'max':
            if (node.format == MpvFormat.mpvFormatByteArray) {
              final ba = node.u.ba.ref;
              if (ba.size > 0) {
                final n = ba.size ~/ 4;
                final src = ba.data.cast<Float>().asTypedList(n);
                bulkMax = Float32List(n)..setAll(0, src);
              }
            }
        }
      }

      if (state == 'ready' &&
          binCount > 0 &&
          durationUs > 0 &&
          bulkMin != null &&
          bulkMax != null &&
          bulkMin.length == binCount &&
          bulkMax.length == binCount) {
        _data = WaveformData(
          min: bulkMin,
          max: bulkMax,
          sourceDuration: Duration(microseconds: durationUs),
        );
        _pollTimer?.cancel();
        _pollTimer = null;
        if (!_ctrl.isClosed) _ctrl.add(_data);
        return;
      }
      if (state == 'failed') {
        // Worker failed (live stream / unsupported protocol). Stop
        // polling — there is nothing further to wait for. The stream
        // stays at `null` until the next track loads.
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    } finally {
      _lib.mpvFreeNodeContents(result);
      calloc.free(result);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
