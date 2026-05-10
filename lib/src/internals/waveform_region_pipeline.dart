// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../models/waveform_region.dart';
import '../mpv_bindings.dart';

/// On-demand region decode pipeline for sample-level zoom.
///
/// Wraps the C-side `waveform-region-request` / `waveform-region-data`
/// property pair into an async request/response API. Each call writes
/// the requested range into the request property, then polls the
/// data property until the C-side worker reports `ready` with a
/// matching range — at which point the PCM byte array is parsed into
/// a [WaveformRegion].
///
/// **Concurrency**: requests are serialised — a new request waits for
/// the previous to settle (or time out) before it kicks. Inside libmpv
/// the worker uses a generation counter so older in-flight decodes
/// are still cancelled if a new request lands mid-decode, but the
/// Dart-side serialisation lets the consumer await each request
/// individually without racing.
@internal
class WaveformRegionPipeline {
  WaveformRegionPipeline({
    required MpvLibrary lib,
    required Pointer<MpvHandle> handle,
    Duration pollInterval = const Duration(milliseconds: 25),
  })  : _lib = lib,
        _handle = handle,
        _pollInterval = pollInterval;

  final MpvLibrary _lib;
  final Pointer<MpvHandle> _handle;
  final Duration _pollInterval;

  Future<WaveformRegion?>? _inFlight;
  bool _disposed = false;

  /// Decodes the [start, end) range of the currently-loaded track
  /// to mono Float32 PCM. Returns `null` if the worker failed (live
  /// stream / unsupported codec) or the request timed out. Each
  /// call serialises after any in-flight request.
  Future<WaveformRegion?> read({
    required Duration start,
    required Duration end,
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (_disposed || _handle == nullptr) {
      return Future.value(null);
    }
    final previous = _inFlight ?? Future<WaveformRegion?>.value(null);
    final next = previous.then((_) => _decodeOne(
        start: start, end: end, timeout: timeout));
    _inFlight = next;
    return next;
  }

  Future<WaveformRegion?> _decodeOne({
    required Duration start,
    required Duration end,
    required Duration timeout,
  }) async {
    if (_disposed) return null;
    final startUs = start.inMicroseconds;
    final endUs = end.inMicroseconds;
    if (endUs <= startUs) return null;

    if (!_writeRequest(startUs, endUs)) return null;

    final deadline = DateTime.now().add(timeout);
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);
      final result = _readRegion();
      if (result == null) continue;
      switch (result.state) {
        case 'ready':
          if (result.region != null &&
              result.region!.start.inMicroseconds == startUs &&
              result.region!.end.inMicroseconds == endUs) {
            return result.region;
          }
          // Different range still landing in the property — keep
          // polling, the C side may be coalescing requests.
          break;
        case 'failed':
          return null;
        default:
          // idle / decoding — keep polling
          break;
      }
    }
    return null;
  }

  bool _writeRequest(int startUs, int endUs) {
    if (_handle == nullptr) return false;
    return using<bool>((arena) {
      final name = 'waveform-region-request'
          .toNativeUtf8(allocator: arena);
      final value = '$startUs,$endUs'.toNativeUtf8(allocator: arena);
      final valuePtr = arena<Pointer<Utf8>>();
      valuePtr.value = value;
      final rc = _lib.mpvSetProperty(
        _handle, name, MpvFormat.mpvFormatString, valuePtr.cast());
      return rc >= 0;
    });
  }

  _RegionSnapshot? _readRegion() {
    if (_handle == nullptr) return null;

    final result = calloc<MpvNode>();
    try {
      final rc = using<int>((arena) {
        final name = 'waveform-region-data'.toNativeUtf8(allocator: arena);
        return _lib.mpvGetProperty(
          _handle,
          name,
          MpvFormat.mpvFormatNode,
          result.cast(),
        );
      });
      if (rc < 0) return null;
      if (result.ref.format != MpvFormat.mpvFormatNodeMap) return null;

      final map = result.ref.u.list.ref;
      String? state;
      var startUs = 0;
      var endUs = 0;
      var sampleRate = 0;
      Float32List? samples;
      for (var i = 0; i < map.num; i++) {
        final key = map.keys[i].cast<Utf8>().toDartString();
        final node = (map.values + i).ref;
        switch (key) {
          case 'state':
            if (node.format == MpvFormat.mpvFormatString) {
              state = node.u.string.cast<Utf8>().toDartString();
            }
          case 'start_us':
            if (node.format == MpvFormat.mpvFormatInt64) {
              startUs = node.u.int64;
            }
          case 'end_us':
            if (node.format == MpvFormat.mpvFormatInt64) {
              endUs = node.u.int64;
            }
          case 'sample_rate':
            if (node.format == MpvFormat.mpvFormatInt64) {
              sampleRate = node.u.int64;
            }
          case 'samples':
            if (node.format == MpvFormat.mpvFormatByteArray) {
              final ba = node.u.ba.ref;
              if (ba.size > 0) {
                final n = ba.size ~/ 4;
                final src = ba.data.cast<Float>().asTypedList(n);
                samples = Float32List(n)..setAll(0, src);
              }
            }
        }
      }

      if (state == null) return null;
      WaveformRegion? region;
      if (state == 'ready' &&
          samples != null &&
          samples.isNotEmpty &&
          sampleRate > 0) {
        region = WaveformRegion(
          start: Duration(microseconds: startUs),
          end: Duration(microseconds: endUs),
          sampleRate: sampleRate,
          samples: samples,
        );
      }
      return _RegionSnapshot(state: state, region: region);
    } finally {
      _lib.mpvFreeNodeContents(result);
      calloc.free(result);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _inFlight = null;
  }
}

class _RegionSnapshot {
  _RegionSnapshot({required this.state, this.region});
  final String state;
  final WaveformRegion? region;
}
