// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../player.dart';

/// Cold-start bring-up: hands the init recipe to the event isolate, then
/// re-opens libmpv on the main isolate and wires the FFI handle, DSP
/// pipelines, finalizer and TLS bundle. Also owns the pre-/post-init option
/// recipes and the `mpv_observe_property` spec list. `_bringUpInIsolate` is
/// the abstract member `_PlayerBase`'s constructor calls; the rest are
/// internal to this mixin.
mixin _InitModule on _PlayerBase {
  @override
  Future<void> _bringUpInIsolate() async {
    final preOpts = _buildPreInitOptions();
    final postOpts = _buildPostInitOptions();
    final observes = _buildObserveSpecs();
    final logLevel = configuration.logLevel == LogLevel.off
        ? null
        : configuration.logLevel.mpvValue;

    final handleAddress = await _eventIsolate.start(
      libraryPath: MpvAudioKit.libraryPath,
      onEvent: _handleEvent,
      preInitOptions: preOpts,
      postInitOptions: postOpts,
      observes: observes,
      logLevel: logLevel,
      wakeupCounterAddress: _wakeupCounterAddress,
    );

    if (_disposed) return;

    // Re-open the library on the main isolate. The OS keeps libmpv
    // mapped after the event isolate's first dlopen, so this resolves
    // in microseconds — no second cold-load cost.
    _lib = MpvLibrary.open(MpvAudioKit.libraryPath);
    _handle = Pointer<MpvHandle>.fromAddress(handleAddress);
    _spectrumPipeline = SpectrumPipeline(lib: _lib, handle: _handle);
    _spectrumPipeline.fftStream.listen(_fftCtrl.add);
    _spectrumPipeline.pcmStream.listen(_pcmStreamCtrl.add);
    _spectrumPipeline.settingsStream.listen(_spectrumCtrl.add);
    _waveformPipeline = WaveformPipeline(lib: _lib, handle: _handle);
    _filterTapPipeline = FilterTapPipeline(lib: _lib, handle: _handle);
    _waveformPipeline.stream.listen(_waveformCtrl.add);

    OrphanHandleTracker.instance.add(_handle);
    _nativeResources = PlayerNativeResources(_lib, _handle);
    playerFinalizer.attach(this, _nativeResources, detach: this);

    // Wire `tls-ca-file` to the bundled CA pem so HTTPS verification
    // works on platforms whose OS trust store the underlying TLS backend
    // cannot read.
    _tlsBundleReady = _autoConfigureTlsCaBundle();
    _bringUpCompleted = true;

    // A waveform subscriber that landed before bring-up finished
    // missed the `onListen` enable — reconcile it now.
    if (_waveformCtrl.hasListener) _waveformPipeline.setEnabled(true);
  }

  Future<void> _autoConfigureTlsCaBundle() async {
    try {
      final path = await TlsCaBundle.extract();
      _autoTlsCaBundlePath = path;
      if (_disposed) return;
      // Mirrors what [setTlsCaFile] does in the network mixin; that
      // method is not visible from this class so we duplicate the two
      // wire operations (property set + state update) inline.
      _prop('tls-ca-file', path);
      _updateField(
        (s) => s.copyWith(tlsCaFile: path),
        _reactives.tlsCaFile,
        path,
      );
    } catch (e, st) {
      // Surface to the internal-log stream; do NOT throw — the player
      // still works for non-HTTPS streams or for consumers that bring
      // their own CA bundle via `setTlsCaFile`.
      _internalLogCtrl.add(
        MpvLogEntry(
          level: LogLevel.warn,
          prefix: 'mpv_audio_kit',
          text: 'Failed to auto-configure tls-ca-file: $e\n$st',
        ),
      );
    }
  }

  /// Recipe of pre-init `mpv_set_option_string` calls executed by the
  /// event isolate before `mpv_initialize`.
  Map<String, String> _buildPreInitOptions() => {
        'vid': 'no',
        'sid': 'no',
        'vo': 'null',
        // Watch-later / resume. Persist only the audio-relevant props (mpv's
        // default list includes video/sub keys this build can't restore).
        'resume-playback': configuration.resumePlayback ? 'yes' : 'no',
        'watch-later-options':
            'start,speed,pitch,volume,mute,audio-delay,af,aid',
        if (configuration.watchLaterDir != null)
          'watch-later-dir': configuration.watchLaterDir!,
        if (configuration.forceSeekable) 'force-seekable': 'yes',
        'hls-bitrate': configuration.hlsBitrate.mpvValue,
        if (configuration.normalizeDownmix) 'audio-normalize-downmix': 'yes',
        if (configuration.demuxerCacheDir != null)
          'demuxer-cache-dir': configuration.demuxerCacheDir!,
        // If the audio device can't be opened (Bluetooth/AirPlay sink gone,
        // a stale device id), fall back to the null AO and keep the position
        // clock running instead of hard-failing playback. The failure is
        // still surfaced through `audio-output-state`.
        'audio-fallback-to-null': 'yes',
        'audio-display': 'embedded-first',
        'cover-art-auto': 'no',
        'image-display-duration': 'inf',
        'keep-open': 'yes',
        'idle': 'yes',
        'osc': 'no',
        'ytdl': 'no',
        'load-stats-overlay': 'no',
        'load-console': 'no',
        'load-commands': 'no',
        'load-auto-profiles': 'no',
        'load-select': 'no',
        'load-context-menu': 'no',
        'load-positioning': 'no',
        'load-scripts': 'no',
        'input-builtin-bindings': 'no',
        'audio-client-name': 'mpv_audio_kit',
      };

  Map<String, String> _buildPostInitOptions() => {
        'volume': configuration.initialVolume.toStringAsFixed(1),
      };

  /// Specs for `mpv_observe_property` — registry props plus the small
  /// out-of-registry set kept here for cross-reference clarity.
  List<MpvObserveSpec> _buildObserveSpecs() {
    final specs = <MpvObserveSpec>[];
    var replyId = 1;
    for (final spec in _registry.specs) {
      specs.add(MpvObserveSpec(spec.name, spec.format, replyId++));
    }
    // Out-of-registry observers. NODE for structured data; STRING for
    // `loop-*` and `audio-device` (cross-referenced from
    // `audio-device-list`).
    final extras = <(String, int)>[
      ('playlist', MpvFormat.mpvFormatNode),
      ('audio-device-list', MpvFormat.mpvFormatNode),
      ('audio-device', MpvFormat.mpvFormatString),
      ('metadata', MpvFormat.mpvFormatNode),
      ('demuxer-cache-state', MpvFormat.mpvFormatNode),
      ('loop-file', MpvFormat.mpvFormatString),
      ('loop-playlist', MpvFormat.mpvFormatString),
    ];
    var extraReplyId = PropertyRegistry.registryReplyIdMax + 1;
    for (final (name, format) in extras) {
      specs.add(MpvObserveSpec(name, format, extraReplyId++));
    }
    return specs;
  }
}
