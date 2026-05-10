// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../models/waveform_data.dart';

/// Persistent sidecar cache for analyzed waveform envelopes.
///
/// Cache key is `sha1(absolutePath + mtimeMs + sizeBytes)`. The
/// digest catches edits, replacements and renames in different
/// directories — a renamed file produces a new key and gets re-
/// analyzed; a moved-but-otherwise-identical file remaps to a new
/// key, also re-analyzed. (We accept this small redundancy in
/// exchange for not having to recompute a content hash, which would
/// re-read the entire audio file.)
///
/// Storage layout:
///
///     <cacheDirectory>/<sha1>.wfm
///
/// File format (little-endian):
///
///     // Header — 28 bytes
///     bytes[8]  magic           = "MAKWAVE\0"
///     uint32    version         = 1
///     uint32    numLevels
///     int64     durationUs
///     uint32    sampleRate
///
///     // Repeated numLevels times
///     uint32    peaksPerSecond
///     uint32    bins
///     Float32   min[bins]
///     Float32   max[bins]
///
/// Eviction: opportunistic, on every write that would push the
/// directory past `maxBytes` (when set). Oldest mtime first.
@internal
class WaveformCache {
  WaveformCache({required this.directory, this.maxBytes});

  final Directory directory;
  final int? maxBytes;

  static const _magic = [0x4D, 0x41, 0x4B, 0x57, 0x41, 0x56, 0x45, 0x00];
  static const _version = 1;
  static const _headerBytes = 28;

  /// Cache key for [path]. Returns `null` when the file is unreadable
  /// (deleted between probe and load, permission error, …).
  Future<String?> keyFor(String path) async {
    try {
      final file = File(path);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) return null;
      final material = utf8.encode(
        '$path|${stat.modified.millisecondsSinceEpoch}|${stat.size}',
      );
      return sha1.convert(material).toString();
    } catch (_) {
      return null;
    }
  }

  File _cacheFile(String key) =>
      File('${directory.path}${Platform.pathSeparator}$key.wfm');

  /// Returns the cached envelope for [key] or `null` if absent /
  /// corrupt. Touches the file's mtime on hit so LRU eviction
  /// preserves recently-used entries.
  Future<WaveformData?> read(String key) async {
    final file = _cacheFile(key);
    if (!await file.exists()) return null;

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return null;
    }
    if (bytes.length < _headerBytes) return null;

    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < _magic.length; i++) {
      if (view.getUint8(i) != _magic[i]) return null;
    }
    final version = view.getUint32(8, Endian.little);
    if (version != _version) return null;
    final numLevels = view.getUint32(12, Endian.little);
    final durationUs = view.getInt64(16, Endian.little);
    final sampleRate = view.getUint32(24, Endian.little);

    final levels = <WaveformLevel>[];
    var offset = _headerBytes;
    for (var L = 0; L < numLevels; L++) {
      if (offset + 8 > bytes.length) return null;
      final pps = view.getUint32(offset, Endian.little);
      final bins = view.getUint32(offset + 4, Endian.little);
      offset += 8;
      final minBytes = bins * 4;
      final maxBytes = bins * 4;
      if (offset + minBytes + maxBytes > bytes.length) return null;
      final min = bytes.buffer.asFloat32List(
        bytes.offsetInBytes + offset, bins);
      offset += minBytes;
      final max = bytes.buffer.asFloat32List(
        bytes.offsetInBytes + offset, bins);
      offset += maxBytes;
      levels.add(WaveformLevel(
        peaksPerSecond: pps,
        // Copy out so the WaveformData is independent of the buffer.
        min: Float32List.fromList(min),
        max: Float32List.fromList(max),
      ));
    }

    // Touch mtime so LRU favours recently-read entries.
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {/* non-fatal */}

    return WaveformData(
      sourceDuration: Duration(microseconds: durationUs),
      sampleRate: sampleRate,
      levels: levels,
    );
  }

  /// Persists [data] under [key]. Triggers LRU eviction first when
  /// [maxBytes] is set and the new entry would push the directory
  /// past the cap.
  Future<void> write(String key, WaveformData data) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final payload = _encode(data);

    if (maxBytes != null) {
      await _evictForIncoming(payload.lengthInBytes);
    }

    final tmp = File('${_cacheFile(key).path}.tmp');
    try {
      await tmp.writeAsBytes(payload, flush: true);
      await tmp.rename(_cacheFile(key).path);
    } catch (_) {
      // Best-effort cleanup of the temp file on failure.
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {/* swallow */}
    }
  }

  /// Removes a single entry. No-op if absent.
  Future<void> evict(String key) async {
    final file = _cacheFile(key);
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {/* non-fatal */}
  }

  /// Removes every cached entry from [directory]. Other files in the
  /// directory (foreign content) are left untouched.
  Future<void> clear() async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.wfm')) {
        try {
          await entity.delete();
        } catch (_) {/* non-fatal */}
      }
    }
  }

  Uint8List _encode(WaveformData data) {
    final levels = data.levels;
    var totalBytes = _headerBytes;
    for (final level in levels) {
      totalBytes += 8 + level.bins * 4 * 2;
    }
    final out = Uint8List(totalBytes);
    final view = ByteData.sublistView(out);

    for (var i = 0; i < _magic.length; i++) {
      view.setUint8(i, _magic[i]);
    }
    view.setUint32(8, _version, Endian.little);
    view.setUint32(12, levels.length, Endian.little);
    view.setInt64(16, data.sourceDuration.inMicroseconds, Endian.little);
    view.setUint32(24, data.sampleRate, Endian.little);

    var offset = _headerBytes;
    for (final level in levels) {
      view.setUint32(offset, level.peaksPerSecond, Endian.little);
      view.setUint32(offset + 4, level.bins, Endian.little);
      offset += 8;
      final minBytes = level.min.buffer.asUint8List(
        level.min.offsetInBytes, level.bins * 4);
      out.setRange(offset, offset + minBytes.length, minBytes);
      offset += minBytes.length;
      final maxBytes = level.max.buffer.asUint8List(
        level.max.offsetInBytes, level.bins * 4);
      out.setRange(offset, offset + maxBytes.length, maxBytes);
      offset += maxBytes.length;
    }

    return out;
  }

  Future<void> _evictForIncoming(int incomingBytes) async {
    final cap = maxBytes;
    if (cap == null) return;

    if (!await directory.exists()) return;
    final entries = <_Entry>[];
    var total = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.wfm')) continue;
      try {
        final stat = await entity.stat();
        entries.add(_Entry(entity, stat.modified, stat.size));
        total += stat.size;
      } catch (_) {/* skip */}
    }

    if (total + incomingBytes <= cap) return;

    entries.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in entries) {
      if (total + incomingBytes <= cap) break;
      try {
        await entry.file.delete();
        total -= entry.size;
      } catch (_) {/* non-fatal */}
    }
  }
}

class _Entry {
  _Entry(this.file, this.modified, this.size);
  final File file;
  final DateTime modified;
  final int size;
}
