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
import '../types/settings/waveform_settings.dart';
import 'waveform_cache.dart';

/// Bulk waveform pipeline.
///
/// Polls mpv's `waveform-data` property at a low rate while a listener
/// is attached. The C-side coordinator decodes the whole track via
/// libav on a worker thread and writes a 3-level mipmap (coarse /
/// medium / fine) into the property. As soon as the coordinator
/// reports `state == "ready"`, the pipeline emits the assembled
/// envelope and stops the timer until the next track-change.
///
/// On track change the player calls [reset]: the pipeline drops the
/// current envelope, emits `null`, and either hits a sidecar cache
/// (if a cache directory is configured and the entry is present) or
/// rearms the polling timer to catch the new file's coordinator.
///
/// Honors [WaveformSettings.enabled]: when off, the pipeline never
/// polls, never reads the cache, and emits only `null`. The C-side
/// coordinator still runs on every FILE_LOADED — the Dart-side flag
/// just controls whether its result is surfaced to consumers.
@internal
class WaveformPipeline {
  WaveformPipeline({
    required MpvLibrary lib,
    required Pointer<MpvHandle> handle,
    WaveformSettings settings = WaveformSettings.disabled,
    Duration pollInterval = const Duration(milliseconds: 200),
  })  : _lib = lib,
        _handle = handle,
        _settings = settings,
        _pollInterval = pollInterval {
    _ctrl = StreamController<WaveformData?>.broadcast(
      onListen: () {
        if (_data != null) _ctrl.add(_data);
        _kick();
      },
      onCancel: () {
        if (_ctrl.hasListener) return;
        _pollTimer?.cancel();
        _pollTimer = null;
      },
    );
    _rebuildCache();
  }

  final MpvLibrary _lib;
  final Pointer<MpvHandle> _handle;
  final Duration _pollInterval;

  WaveformSettings _settings;
  WaveformCache? _cache;

  late final StreamController<WaveformData?> _ctrl;
  Timer? _pollTimer;
  WaveformData? _data;
  bool _disposed = false;
  int _resetTicket = 0;

  Stream<WaveformData?> get stream => _ctrl.stream;

  /// Reconfigures the analyzer at runtime. The new policy applies
  /// from the next track-load onward; the current envelope (if any)
  /// is retained until the next [reset].
  void setSettings(WaveformSettings settings) {
    if (_disposed || settings == _settings) return;
    _settings = settings;
    _rebuildCache();
    if (!settings.enabled) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _data = null;
      if (!_ctrl.isClosed) _ctrl.add(null);
    } else if (_data == null && _ctrl.hasListener) {
      _kick();
    }
  }

  /// Drops the current envelope and emits `null` so renderers clear
  /// stale data on the track-change boundary. Then either resolves
  /// the new track from the cache (on hit) or rearms the polling
  /// timer (on miss), provided [WaveformSettings.enabled] is `true`
  /// and someone is listening.
  void reset() {
    if (_disposed) return;
    _data = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _resetTicket++;
    if (!_ctrl.isClosed) _ctrl.add(null);
    if (_settings.enabled && _ctrl.hasListener) _kick();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_ctrl.isClosed) await _ctrl.close();
  }

  void _rebuildCache() {
    final dir = _settings.cacheDirectory;
    _cache = (dir != null)
        ? WaveformCache(directory: dir, maxBytes: _settings.maxCacheBytes)
        : null;
  }

  void _kick() {
    if (!_settings.enabled || _disposed) return;
    final ticket = _resetTicket;
    final cache = _cache;
    if (cache != null) {
      _tryCacheRead(cache, ticket).then((hit) {
        if (hit || _disposed || ticket != _resetTicket) return;
        _armTimer();
      });
    } else {
      _armTimer();
    }
  }

  Future<bool> _tryCacheRead(WaveformCache cache, int ticket) async {
    final url = _readStreamOpenFilename();
    if (url == null || url.isEmpty) return false;
    final key = await cache.keyFor(url);
    if (key == null || _disposed || ticket != _resetTicket) return false;
    final cached = await cache.read(key);
    if (cached == null || _disposed || ticket != _resetTicket) return false;
    _data = cached;
    if (!_ctrl.isClosed) _ctrl.add(cached);
    return true;
  }

  void _armTimer() {
    if (_disposed) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    _poll();
  }

  String? _readStreamOpenFilename() {
    if (_handle == nullptr) return null;
    return using<String?>((arena) {
      final name = 'stream-open-filename'.toNativeUtf8(allocator: arena);
      final out = arena<Pointer<Utf8>>();
      final rc = _lib.mpvGetProperty(
        _handle, name, MpvFormat.mpvFormatString, out.cast());
      if (rc < 0) return null;
      try {
        final ptr = out.value;
        if (ptr == nullptr) return null;
        return ptr.toDartString();
      } finally {
        // mpv allocated the string; tell it to free.
        _lib.mpvFree(out.value.cast());
      }
    });
  }

  void _poll() {
    if (_disposed || _data != null || !_settings.enabled) return;
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

      final map = result.ref.u.list.ref;
      String? state;
      var durationUs = 0;
      var sampleRate = 0;
      List<WaveformLevel>? levels;
      for (var i = 0; i < map.num; i++) {
        final keyPtr = map.keys[i];
        final key = keyPtr.cast<Utf8>().toDartString();
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
          case 'sample_rate':
            if (node.format == MpvFormat.mpvFormatInt64) {
              sampleRate = node.u.int64;
            }
          case 'levels':
            if (node.format == MpvFormat.mpvFormatNodeArray) {
              levels = _parseLevels(node.u.list.ref);
            }
        }
      }

      if (state == 'ready' &&
          durationUs > 0 &&
          sampleRate > 0 &&
          levels != null &&
          levels.isNotEmpty) {
        final data = WaveformData(
          sourceDuration: Duration(microseconds: durationUs),
          sampleRate: sampleRate,
          levels: levels,
        );
        _data = data;
        _pollTimer?.cancel();
        _pollTimer = null;
        if (!_ctrl.isClosed) _ctrl.add(data);
        // Persist to cache asynchronously — fire and forget.
        _writeCache(data);
        return;
      }
      if (state == 'failed') {
        // Worker failed (live stream / unsupported protocol). Stop
        // polling — there is nothing further to wait for.
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    } finally {
      _lib.mpvFreeNodeContents(result);
      calloc.free(result);
    }
  }

  List<WaveformLevel>? _parseLevels(MpvNodeList array) {
    final result = <WaveformLevel>[];
    for (var i = 0; i < array.num; i++) {
      final entry = (array.values + i).ref;
      if (entry.format != MpvFormat.mpvFormatNodeMap) return null;
      final map = entry.u.list.ref;
      var pps = 0;
      var bins = 0;
      Float32List? min;
      Float32List? max;
      for (var j = 0; j < map.num; j++) {
        final key = map.keys[j].cast<Utf8>().toDartString();
        final node = (map.values + j).ref;
        switch (key) {
          case 'peaks_per_second':
            if (node.format == MpvFormat.mpvFormatInt64) {
              pps = node.u.int64;
            }
          case 'bins':
            if (node.format == MpvFormat.mpvFormatInt64) {
              bins = node.u.int64;
            }
          case 'min':
            if (node.format == MpvFormat.mpvFormatByteArray) {
              final ba = node.u.ba.ref;
              if (ba.size > 0) {
                final n = ba.size ~/ 4;
                final src = ba.data.cast<Float>().asTypedList(n);
                min = Float32List(n)..setAll(0, src);
              }
            }
          case 'max':
            if (node.format == MpvFormat.mpvFormatByteArray) {
              final ba = node.u.ba.ref;
              if (ba.size > 0) {
                final n = ba.size ~/ 4;
                final src = ba.data.cast<Float>().asTypedList(n);
                max = Float32List(n)..setAll(0, src);
              }
            }
        }
      }
      if (bins == 0 || min == null || max == null ||
          min.length != bins || max.length != bins) {
        return null;
      }
      result.add(WaveformLevel(
        peaksPerSecond: pps,
        min: min,
        max: max,
      ));
    }
    return result;
  }

  void _writeCache(WaveformData data) {
    final cache = _cache;
    if (cache == null) return;
    final url = _readStreamOpenFilename();
    if (url == null || url.isEmpty) return;
    // Fire and forget — cache I/O is best effort, not load-bearing.
    () async {
      final key = await cache.keyFor(url);
      if (key == null) return;
      try {
        await cache.write(key, data);
      } catch (_) {/* swallow */}
    }();
  }
}
