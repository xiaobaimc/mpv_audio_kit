// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../models/fft_frame.dart';
import '../models/pcm_frame.dart';
import '../mpv_bindings.dart';
import '../types/settings/spectrum_settings.dart';
import 'band_processor.dart';
import 'pcm_node_decode.dart';

/// Real-time FFT + raw PCM pipeline backed by the mpv `pcm-tap-frame`
/// property.
///
/// Owns two broadcast streams ([spectrumStream], [pcmStream]) and a
/// poll loop that calls `mpv_get_property("pcm-tap-frame")` at the
/// configured emit rate. The poll loop is **lazy**: it starts on the
/// first listener (to either stream) and stops on the last cancel.
///
/// The pipeline:
///   1. Poll the property → MAP_NODE { sample_rate, channels, pts_ns, samples }.
///   2. Skip emit when `pts_ns` matches the previous poll (no new audio).
///   3. Mix down to mono (mean of channels).
///   4. Multiply by the configured window function.
///   5. Real FFT (fftea) → magnitude per bin.
///   6. Power → 10·log₁₀ → clip [minDb, maxDb] → normalise [0, 1].
///   7. Aggregate bins into log-spaced bands (mean per band).
///   8. Apply asymmetric EMA on the bands (fast attack, slow release).
///   9. Emit [FftFrame] (raw bins + smoothed bands) and [PcmFrame].
@internal
class SpectrumPipeline {
  SpectrumPipeline({
    required MpvLibrary lib,
    required Pointer<MpvHandle> handle,
  })  : _lib = lib,
        _handle = handle {
    _fftCtrl = StreamController<FftFrame>.broadcast(
      onListen: () {
        _fftActive = true;
        _maybeStart();
      },
      onCancel: () {
        _fftActive = false;
        _maybeStop();
      },
    );
    _pcmCtrl = StreamController<PcmFrame>.broadcast(
      onListen: () {
        _pcmActive = true;
        _maybeStart();
      },
      onCancel: () {
        _pcmActive = false;
        _maybeStop();
      },
    );
    // [_settingsCtrl] is NOT lazy — it carries config-change events,
    // not data, and must always be listenable so the matching
    // `Player.stream.spectrumSettings` can observe mutations even
    // before the FFT poll loop is armed.
    _settingsCtrl = StreamController<SpectrumSettings>.broadcast();
  }

  final MpvLibrary _lib;
  final Pointer<MpvHandle> _handle;

  late final StreamController<FftFrame> _fftCtrl;
  late final StreamController<PcmFrame> _pcmCtrl;
  late final StreamController<SpectrumSettings> _settingsCtrl;

  Stream<FftFrame> get fftStream => _fftCtrl.stream;
  Stream<PcmFrame> get pcmStream => _pcmCtrl.stream;
  Stream<SpectrumSettings> get settingsStream => _settingsCtrl.stream;

  SpectrumSettings _settings = SpectrumSettings.defaults;
  SpectrumSettings get settings => _settings;

  bool _fftActive = false;
  bool _pcmActive = false;
  bool _disposed = false;
  Timer? _pollTimer;
  // Shared FFT / windowing / EMA pipeline — same component the
  // public [BandProcessor] exposes, so global and per-filter
  // spectrum surfaces stay byte-identical when fed equivalent PCM.
  late final BandProcessor _processor = BandProcessor(_settings);
  int _lastPolledPtsNs = 0;

  /// Replaces the pipeline configuration. Reallocates FFT / window /
  /// EMA memory only on changes that require it; the poll timer is
  /// re-armed only when [SpectrumSettings.emitInterval] changes.
  void setSettings(SpectrumSettings next) {
    final emitChanged = next.emitInterval != _settings.emitInterval;
    _settings = next;
    _processor.setSettings(next);
    if (emitChanged && _pollTimer != null) {
      _pollTimer!.cancel();
      _pollTimer = Timer.periodic(_settings.emitInterval, (_) => _poll());
    }
    if (!_settingsCtrl.isClosed) _settingsCtrl.add(next);
  }

  void _maybeStart() {
    if (_disposed || _pollTimer != null) return;
    if (_handle == nullptr) return;
    // [BandProcessor] allocates lazily on first [process], so we don't
    // need to prime anything here — just arm the poll loop.
    _pollTimer = Timer.periodic(_settings.emitInterval, (_) => _poll());
  }

  void _maybeStop() {
    if (_fftActive || _pcmActive) return;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _poll() {
    if (_disposed) return;
    if (!_fftActive && !_pcmActive) return;
    if (_handle == nullptr) return;

    final result = calloc<MpvNode>();
    try {
      final rc = using<int>((arena) {
        final name = 'pcm-tap-frame'.toNativeUtf8(allocator: arena);
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

      var sampleRate = 0;
      var channels = 0;
      var ptsNs = 0;
      Float32List? samples;

      for (var i = 0; i < list.num; i++) {
        final keyPtr = list.keys[i];
        final key = keyPtr.cast<Utf8>().toDartString();
        final node = (list.values + i).ref;
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

      if (samples == null || sampleRate <= 0 || channels <= 0 || ptsNs == 0) {
        return;
      }
      if (ptsNs == _lastPolledPtsNs) return;
      _lastPolledPtsNs = ptsNs;

      final timestamp = Duration(microseconds: ptsNs ~/ 1000);
      final pcm = PcmFrame(
        samples: samples,
        timestamp: timestamp,
        sampleRate: sampleRate,
        channels: channels,
      );

      if (_pcmActive && !_pcmCtrl.isClosed) {
        _pcmCtrl.add(pcm);
      }

      if (_fftActive && !_fftCtrl.isClosed) {
        final frame = _processor.process(pcm);
        if (frame != null) _fftCtrl.add(frame);
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
    if (!_fftCtrl.isClosed) await _fftCtrl.close();
    if (!_pcmCtrl.isClosed) await _pcmCtrl.close();
    if (!_settingsCtrl.isClosed) await _settingsCtrl.close();
  }
}
