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
      var rangeStartUs = 0;
      var rangeEndUs = 0;
      Float32List? min;
      Float32List? max;
      Uint8List? filled;
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
          case 'range_start_us':
            if (node.format == MpvFormat.mpvFormatInt64) {
              rangeStartUs = node.u.int64;
            }
          case 'range_end_us':
            if (node.format == MpvFormat.mpvFormatInt64) {
              rangeEndUs = node.u.int64;
            }
          case 'min':
            min = _decodeFloat32(node);
          case 'max':
            max = _decodeFloat32(node);
          case 'filled':
            filled = _decodeBytes(node);
        }
      }

      final ready = state == 'ready';
      final progressive = state == 'progressive';
      final rolling = state == 'rolling';

      final haveBins = min != null &&
          max != null &&
          min.isNotEmpty &&
          min.length == max.length;

      // Fall back to all-covered if the native side omitted/mismatched the
      // flags, so the renderer never misreads it.
      Uint8List safeFilled(Float32List m) =>
          (filled != null && filled.length == m.length)
              ? filled
              : (Uint8List(m.length)..fillRange(0, m.length, 1));

      // ROLLING (true live, unknown total): a sliding window keyed to the
      // demuxer cache. The native side reports the absolute range it holds;
      // the envelope grows and slides, so never cache it — keep polling.
      if (rolling && haveBins && rangeEndUs > rangeStartUs) {
        final data = WaveformData(
          start: Duration(microseconds: rangeStartUs),
          duration: Duration(microseconds: rangeEndUs - rangeStartUs),
          min: min,
          max: max,
          filled: safeFilled(min),
          live: true,
        );
        _emit(data);
        return;
      }

      if ((ready || progressive) && durationUs > 0 && haveBins) {
        final data = WaveformData(
          duration: Duration(microseconds: durationUs),
          min: min,
          max: max,
          filled: safeFilled(min),
        );
        if (ready) {
          // Bulk envelope is final: cache it and stop polling.
          _data = data;
          _pollTimer?.cancel();
          _pollTimer = null;
        }
        // Progressive (network) envelope grows: leave _data null and the
        // timer running so each poll drives the native fold and emits the
        // freshly-grown envelope.
        _emit(data);
        return;
      }
      if (state == 'failed') {
        // No envelope is coming (true live / unsupported). Stop polling
        // and clear — there is nothing further to wait for.
        _pollTimer?.cancel();
        _pollTimer = null;
        _emit(null);
      }
    } catch (_) {
      // A single malformed / unexpected waveform-data node must never
      // escape the Timer.periodic callback: an uncaught throw there would
      // tear down the poll loop and freeze the waveform until app restart.
      // Swallow it — the node is freed in `finally` and the next tick
      // retries against fresh native state.
    } finally {
      _lib.mpvFreeNodeContents(result);
      calloc.free(result);
    }
  }

  /// Copies a byte-array node holding little-endian Float32 samples
  /// into a fresh [Float32List]. The bytes are copied out first — this
  /// detaches the result from the mpv-owned buffer freed at the end of the
  /// poll AND removes any alignment dependency (the mpv buffer carries no
  /// 4-byte alignment guarantee, so `cast<Float>()` on it would be unsafe).
  /// Decoded as explicit little-endian, the layout the native side writes.
  Float32List? _decodeFloat32(MpvNode node) {
    if (node.format != MpvFormat.mpvFormatByteArray) return null;
    final ba = node.u.ba.ref;
    if (ba.size < 4) return null;
    final n = ba.size ~/ 4;
    final bytes = Uint8List.fromList(ba.data.cast<Uint8>().asTypedList(n * 4));
    final view = bytes.buffer.asByteData();
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = view.getFloat32(i * 4, Endian.little);
    }
    return out;
  }

  /// Copies a byte-array node (one byte per bin) into a fresh [Uint8List],
  /// detaching it from the mpv-owned buffer freed at the end of the poll.
  Uint8List? _decodeBytes(MpvNode node) {
    if (node.format != MpvFormat.mpvFormatByteArray) return null;
    final ba = node.u.ba.ref;
    if (ba.size <= 0) return null;
    final src = ba.data.cast<Uint8>().asTypedList(ba.size);
    return Uint8List(ba.size)..setAll(0, src);
  }
}
