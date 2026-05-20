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

/// Static waveform pipeline.
///
/// Listener-gated by [setEnabled]: while a listener is attached to
/// [PlayerStream.waveform] the player writes the `waveform-enabled`
/// mpv property `true` (the native analyzer only runs while this flag
/// is set) and the pipeline polls `waveform-data` on a low-rate timer.
/// On the last cancel the player writes `waveform-enabled` `false` and
/// the timer stops — an idle waveform costs nothing.
///
/// As soon as the analyzer reports `state == "ready"` the assembled
/// envelope is emitted once via [stream] and the timer stops until the
/// next track-change. On track change the player calls [reset]: the
/// pipeline drops the current envelope, emits `null`, and rearms the
/// timer if still enabled.
@internal
class WaveformPipeline {
  WaveformPipeline({
    required MpvLibrary lib,
    required Pointer<MpvHandle> handle,
    Duration pollInterval = const Duration(milliseconds: 120),
  })  : _lib = lib,
        _handle = handle,
        _pollInterval = pollInterval;

  final MpvLibrary _lib;
  final Pointer<MpvHandle> _handle;
  final Duration _pollInterval;

  final StreamController<WaveformData?> _ctrl =
      StreamController<WaveformData?>.broadcast();
  Timer? _pollTimer;
  WaveformData? _data;
  bool _enabled = false;
  bool _disposed = false;

  Stream<WaveformData?> get stream => _ctrl.stream;

  /// Arms or disarms the analyzer. Driven by the `onListen` / `onCancel`
  /// of the player's `waveform` controller. Writes the
  /// `waveform-enabled` mpv property and starts / stops polling.
  void setEnabled(bool enabled) {
    if (_disposed || enabled == _enabled) return;
    _enabled = enabled;
    _writeEnabledProperty(enabled);
    if (enabled) {
      if (_data != null) {
        _emit(_data);
      } else {
        _armTimer();
      }
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// Drops the current envelope and emits `null` so renderers clear
  /// stale data on the track-change boundary. Rearms the polling timer
  /// when the analyzer is still enabled.
  void reset() {
    if (_disposed) return;
    _data = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _emit(null);
    if (_enabled) _armTimer();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_ctrl.isClosed) await _ctrl.close();
  }

  void _emit(WaveformData? data) {
    if (!_ctrl.isClosed) _ctrl.add(data);
  }

  void _writeEnabledProperty(bool enabled) {
    if (_handle == nullptr) return;
    using<void>((arena) {
      final name = 'waveform-enabled'.toNativeUtf8(allocator: arena);
      final value = (enabled ? 'yes' : 'no').toNativeUtf8(allocator: arena);
      _lib.mpvSetPropertyString(_handle, name, value);
    });
  }

  void _armTimer() {
    if (_disposed || _data != null) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    _poll();
  }

  void _poll() {
    if (_disposed || _data != null || _handle == nullptr) return;

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

      final map = result.ref.u.list.ref;
      String? state;
      var durationUs = 0;
      Float32List? min;
      Float32List? max;
      for (var i = 0; i < map.num; i++) {
        final key = map.keys[i].cast<Utf8>().toDartString();
        final node = (map.values + i).ref;
        switch (key) {
          case 'state':
            if (node.format == MpvFormat.mpvFormatString) {
              state = node.u.string.cast<Utf8>().toDartString();
            }
          case 'duration_us':
            if (node.format == MpvFormat.mpvFormatInt64) {
              durationUs = node.u.int64;
            }
          case 'min':
            min = _decodeFloat32(node);
          case 'max':
            max = _decodeFloat32(node);
        }
      }

      if (state == 'ready' &&
          durationUs > 0 &&
          min != null &&
          max != null &&
          min.isNotEmpty &&
          min.length == max.length) {
        final data = WaveformData(
          duration: Duration(microseconds: durationUs),
          min: min,
          max: max,
        );
        _data = data;
        _pollTimer?.cancel();
        _pollTimer = null;
        _emit(data);
        return;
      }
      if (state == 'failed') {
        // Analyzer failed (live stream / unsupported protocol). Stop
        // polling and clear — there is nothing further to wait for.
        _pollTimer?.cancel();
        _pollTimer = null;
        _emit(null);
      }
    } finally {
      _lib.mpvFreeNodeContents(result);
      calloc.free(result);
    }
  }

  /// Copies a byte-array node holding little-endian Float32 samples
  /// into a fresh [Float32List]. The copy detaches the result from the
  /// mpv-owned buffer freed at the end of the poll.
  Float32List? _decodeFloat32(MpvNode node) {
    if (node.format != MpvFormat.mpvFormatByteArray) return null;
    final ba = node.u.ba.ref;
    if (ba.size <= 0) return null;
    final n = ba.size ~/ 4;
    final src = ba.data.cast<Float>().asTypedList(n);
    return Float32List(n)..setAll(0, src);
  }
}
