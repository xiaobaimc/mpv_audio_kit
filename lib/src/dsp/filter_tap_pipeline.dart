// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../models/pcm_frame.dart';
import '../mpv_bindings.dart';
import 'pcm_node_decode.dart';

/// Upper bound on the channel count reported by the native filter tap.
///
/// The native side clamps to this before writing the ring, so a well-formed
/// frame is always within bound. This mirror is a defensive guard: if the two
/// sides ever drift, a desynced `channels` value can't build a bogus
/// `PcmFrame` downstream.
const int _kMaxTapChannels = 8;

/// Per-filter pre/post audio tap pipeline.
///
/// Backed by the `audio-tap-frames` and `analyzer-taps` properties
/// added by the libmpv filter-label-tap patch. The pipeline:
///
///   1. tracks per-`(name, side)` subscriber counts and writes a
///      comma-separated list of currently-needed filter names to
///      `analyzer-taps`. The C side activates the matching hook in
///      `user_wrapper_process` only for those names.
///   2. polls `audio-tap-frames` at a configurable cadence while at
///      least one stream has a listener; parses the MAP_NODE into
///      per-filter [PcmFrame]s and dispatches them on broadcast
///      controllers keyed by `(name, side)`.
///
/// Idle cost is exactly zero — the polling timer is unarmed and the
/// active-list is empty until the first listener attaches.
@internal
class FilterTapPipeline {
  FilterTapPipeline({
    required MpvLibrary lib,
    required Pointer<MpvHandle> handle,
    // 33 ms ≈ 30 Hz — matches the lib's spectrum pipeline default.
    // The C side now returns the slice of the rolling ring aligned
    // to the AO playback PTS, so the slice walks forward smoothly
    // at the audio output rate regardless of the chain's bursty
    // write cadence. 30 Hz reads are enough; the slice content
    // changes every poll because `playing_audio_pts` is monotonic.
    Duration pollInterval = const Duration(milliseconds: 33),
  })  : _lib = lib,
        _handle = handle,
        _pollInterval = pollInterval;

  final MpvLibrary _lib;
  final Pointer<MpvHandle> _handle;
  final Duration _pollInterval;

  // (name, side) → broadcast controller. Lazy-created on first
  // listener; deactivated when the last subscriber cancels.
  final Map<_TapKey, StreamController<PcmFrame>> _controllers = {};
  // Refcount per (name, side) — drives the analyzer-taps CSV.
  final Map<_TapKey, int> _refs = {};
  // Last native write generation (ring `seq`) dispatched per (name, side).
  // Lets the poll loop skip a redundant decode + add() when the ring is
  // unchanged (e.g. while paused / at EOF the writer isn't advancing it).
  final Map<_TapKey, int> _lastSeq = {};

  Timer? _pollTimer;
  bool _disposed = false;

  /// Returns a broadcast stream of PCM frames captured **before**
  /// [filterName] is applied. The first listener arms the tap; the
  /// last cancel disarms it. Live streams: the stream may emit no
  /// frames until audio actually flows through the chain.
  Stream<PcmFrame> tapPre(String filterName) =>
      _streamFor(_mpvName(filterName), false);

  /// Same as [tapPre] but captures the frame **after** [filterName]
  /// has processed it.
  Stream<PcmFrame> tapPost(String filterName) =>
      _streamFor(_mpvName(filterName), true);

  /// mpv exposes every libavfilter filter under the `lavfi-` prefix
  /// inside the user-filter chain — `u->name` for `equalizer` reads
  /// as `"lavfi-equalizer"`. The pipeline keeps the prefix in every
  /// internal map / CSV write so `find_slot()` on the C side matches.
  /// The public API hides it.
  static String _mpvName(String publicName) => 'lavfi-$publicName';

  Stream<PcmFrame> _streamFor(String name, bool isPost) {
    if (_disposed) {
      return const Stream<PcmFrame>.empty();
    }
    final key = _TapKey(name, isPost);
    return _controllers
        .putIfAbsent(key, () {
          late StreamController<PcmFrame> ctrl;
          ctrl = StreamController<PcmFrame>.broadcast(
            onListen: () => _onListen(key),
            onCancel: () {
              if (!ctrl.hasListener) _onCancelLast(key);
            },
          );
          return ctrl;
        })
        .stream;
  }

  void _onListen(_TapKey key) {
    if (_disposed) return;
    final next = (_refs[key] ?? 0) + 1;
    _refs[key] = next;
    if (next == 1) _writeActiveList();
    if (_pollTimer == null) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
      _poll();
    }
  }

  void _onCancelLast(_TapKey key) {
    if (_disposed) return;
    final cur = _refs[key] ?? 0;
    if (cur <= 1) {
      _refs.remove(key);
    } else {
      _refs[key] = cur - 1;
    }
    if (_refs.isEmpty) {
      _writeActiveList();
      _pollTimer?.cancel();
      _pollTimer = null;
    } else {
      _writeActiveList();
    }
  }

  /// Builds the `analyzer-taps` CSV from the union of every distinct
  /// filter name with at least one (pre or post) refcount > 0, and
  /// pushes it to mpv. The C side replaces its active set on every
  /// write; an empty CSV disables every tap.
  void _writeActiveList() {
    final names = <String>{};
    for (final k in _refs.keys) {
      names.add(k.name);
    }
    final csv = names.join(',');
    using<void>((arena) {
      final n = 'analyzer-taps'.toNativeUtf8(allocator: arena);
      final v = csv.toNativeUtf8(allocator: arena);
      _lib.mpvSetPropertyString(_handle, n, v);
    });
  }

  void _poll() {
    if (_disposed) return;
    if (_handle == nullptr) return;
    if (_refs.isEmpty) return;

    final result = calloc<MpvNode>();
    try {
      final rc = using<int>((arena) {
        final name = 'audio-tap-frames'.toNativeUtf8(allocator: arena);
        return _lib.mpvGetProperty(
          _handle,
          name,
          MpvFormat.mpvFormatNode,
          result.cast(),
        );
      });
      if (rc < 0) return;
      if (result.ref.format != MpvFormat.mpvFormatNodeMap) return;
      _parseRoot(result.ref.u.list.ref);
    } finally {
      _lib.mpvFreeNodeContents(result);
      calloc.free(result);
    }
  }

  void _parseRoot(MpvNodeList list) {
    // root: { filterName: { pre: <ring>, post: <ring> } }
    for (var i = 0; i < list.num; i++) {
      final filterName = list.keys[i].cast<Utf8>().toDartString();
      final entry = (list.values + i).ref;
      if (entry.format != MpvFormat.mpvFormatNodeMap) continue;
      final sides = entry.u.list.ref;
      for (var j = 0; j < sides.num; j++) {
        final sideKey = sides.keys[j].cast<Utf8>().toDartString();
        final isPost = sideKey == 'post';
        final ringNode = (sides.values + j).ref;
        if (ringNode.format != MpvFormat.mpvFormatNodeMap) continue;
        final key = _TapKey(filterName, isPost);
        final ctrl = _controllers[key];
        if (ctrl == null || !ctrl.hasListener) continue;
        final ring = ringNode.u.list.ref;
        // Skip the decode + dispatch when the native write generation is
        // unchanged since the last poll. The C side bumps the ring `seq`
        // on every write and holds it stable while paused / at EOF, so an
        // unchanged seq means an identical slice — re-emitting it only
        // churns a Float32List + StreamController.add() for no new data.
        // seq == 0 means "unavailable"; fall back to always emitting.
        final seq = _ringSeq(ring);
        if (seq != 0 && _lastSeq[key] == seq) continue;
        _lastSeq[key] = seq;
        final frame = _decodeRing(ring);
        if (frame == null) continue;
        if (!ctrl.isClosed) ctrl.add(frame);
      }
    }
  }

  /// Reads just the native write generation (`seq`) from a ring node,
  /// without decoding the samples. Returns 0 when the key is absent.
  int _ringSeq(MpvNodeList ring) {
    for (var i = 0; i < ring.num; i++) {
      if (ring.keys[i].cast<Utf8>().toDartString() == 'seq') {
        final node = (ring.values + i).ref;
        return node.format == MpvFormat.mpvFormatInt64 ? node.u.int64 : 0;
      }
    }
    return 0;
  }

  PcmFrame? _decodeRing(MpvNodeList ring) {
    var sampleRate = 0;
    var channels = 0;
    var ptsNs = 0;
    Float32List? samples;
    for (var i = 0; i < ring.num; i++) {
      final key = ring.keys[i].cast<Utf8>().toDartString();
      final node = (ring.values + i).ref;
      switch (key) {
        case 'sample_rate':
          if (node.format == MpvFormat.mpvFormatInt64) {
            sampleRate = node.u.int64;
          }
        case 'channels':
          if (node.format == MpvFormat.mpvFormatInt64) {
            channels = node.u.int64;
          }
        case 'pts_ns':
          if (node.format == MpvFormat.mpvFormatInt64) {
            ptsNs = node.u.int64;
          }
        case 'samples':
          samples = decodeInterleavedFloat32(node);
      }
    }
    if (samples == null ||
        sampleRate <= 0 ||
        channels <= 0 ||
        channels > _kMaxTapChannels ||
        ptsNs == 0) {
      return null;
    }
    return PcmFrame(
      samples: samples,
      timestamp: Duration(microseconds: ptsNs ~/ 1000),
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    // Best-effort: clear analyzer-taps so the C side stops capturing.
    using<void>((arena) {
      final n = 'analyzer-taps'.toNativeUtf8(allocator: arena);
      final v = ''.toNativeUtf8(allocator: arena);
      _lib.mpvSetPropertyString(_handle, n, v);
    });
    final closes = <Future<void>>[];
    for (final c in _controllers.values) {
      if (!c.isClosed) closes.add(c.close());
    }
    _controllers.clear();
    _refs.clear();
    _lastSeq.clear();
    await Future.wait(closes);
  }
}

class _TapKey {
  final String name;
  final bool isPost;
  const _TapKey(this.name, this.isPost);

  @override
  bool operator ==(Object other) =>
      other is _TapKey && other.name == name && other.isPost == isPost;
  @override
  int get hashCode => Object.hash(name, isPost);
}
