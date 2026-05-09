// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../internals/cover_art_extractor.dart';
import '../internals/filter_tap_pipeline.dart';
import '../internals/player_finalizer.dart';
import '../internals/spectrum_pipeline.dart';
import '../internals/waveform_pipeline.dart';
import '../models/fft_frame.dart';
import '../models/pcm_frame.dart';
import '../models/waveform_data.dart';
import '../models/cover_art.dart';
import '../internals/event_isolate.dart';
import '../events/mpv_exception.dart';
import 'audio_output_error.dart';
import 'lifecycle_transitions.dart';
import '../reactive/node_parsers.dart';
import '../internals/library_loader.dart';
import '../mpv_bindings.dart' hide MpvEndFileReason;
import '../internals/orphan_handle_tracker.dart';
import '../reactive/default_specs.dart';
import '../reactive/property_registry.dart';
import '../reactive/reactive_property.dart';
import '../internals/duration_seconds.dart';
import '../internals/tls_ca_bundle.dart';
import '../internals/uri_resolver.dart';

import '../types/sealed/track.dart';
import '../types/enums/loop.dart';
import '../models/chapter.dart';
import '../models/media.dart';
import '../models/playlist.dart';
import '../types/sealed/channels.dart';
import '../models/device.dart';
import '../types/enums/format.dart';
import '../types/enums/cover.dart';
import '../types/enums/gapless.dart';
import '../types/enums/hook.dart';
import '../types/enums/log_level.dart';
import '../types/settings/audio_effects_settings.dart';
import '../types/settings/cache_settings.dart';
import '../types/settings/spectrum_settings.dart';
import '../events/mpv_log_entry.dart';
import '../events/mpv_hook_event.dart';
import '../events/mpv_player_error.dart';
import 'player_api.dart';
import 'player_configuration.dart';
import 'player_state.dart';
import '../types/settings/replay_gain_settings.dart';
import '../types/enums/spdif.dart';
import 'player_stream.dart';

export '../models/cover_art.dart';
export '../types/enums/loop.dart';
export '../models/media.dart';
export '../models/playlist.dart';
export '../types/sealed/channels.dart';
export '../models/device.dart';
export '../types/enums/format.dart';
export '../models/audio_params.dart';
export '../types/sealed/track.dart';
export '../types/enums/audio_effects.dart';
export '../types/settings/audio_effects_settings.dart';
export '../events/mpv_log_entry.dart';
export '../events/mpv_hook_event.dart';
export '../types/settings/spectrum_settings.dart';
export 'player_configuration.dart';
export 'player_state.dart';
export 'player_stream.dart';

part 'player_playback.part.dart';
part 'player_playlist.part.dart';
part 'player_audio.part.dart';
part 'player_network.part.dart';
part 'player_hooks.part.dart';

/// A high-performance audio player powered by libmpv.
///
/// Implements [PlayerApi] so test code can mock the player without
/// dragging in the FFI handle and event isolate
/// (`class MockPlayer extends Mock implements PlayerApi {}`).
class Player extends _PlayerBase
    with
        _PlaybackModule,
        _PlaylistModule,
        _AudioModule,
        _NetworkModule,
        _HooksModule
    implements PlayerApi {
  /// Creates a [Player] instance with optional [configuration].
  Player({super.configuration});

  /// Test-only. The event isolate writes to [wakeupCounterAddress] on
  /// every wakeup — a bogus value corrupts process memory.
  @visibleForTesting
  Player.testInstrumented({
    PlayerConfiguration configuration = const PlayerConfiguration(),
    required int wakeupCounterAddress,
  }) : super(
          configuration: configuration,
          wakeupCounterAddress: wakeupCounterAddress,
        );

  // --- Public Specialized API ---

  /// Opens a [Media] and optionally starts playback immediately.
  ///
  /// `pause` is set as a global property before `loadfile` so the
  /// property observer always fires on the first-load transition
  /// (a per-file option can skip the `PROPERTY_CHANGE` emit).
  /// Rapid back-to-back `open()` calls don't race: `loadfile replace`
  /// aborts the previous load, so the last `(pause, loadfile)` pair wins.
  Future<void> open(Media media, {bool? play}) async {
    _checkNotDisposed();
    await _ready;
    _validateHttpHeaders(media.httpHeaders);
    _mediaCache.clear();
    _mediaCache[media.uri] = media;
    // Gate on the trust-bundle Future so the first HTTPS load always
    // sees `tls-ca-file` populated. Awaited in parallel with URI
    // resolution so the bundle write overlaps with content://-handle
    // detach / asset materialisation.
    final tls = _tlsBundleReady;
    final resolved = await resolveUri(media.uri);
    await tls;
    if (_disposed) {
      await resolved.dispose?.call();
      return;
    }
    _mediaCache[resolved.uri] = media;
    final shouldPlay = play ?? configuration.autoPlay;
    // Drop visible per-track state synchronously — cover art, chapter
    // list and current chapter index — so a UI that reads the state
    // immediately after `open()` returns doesn't briefly render the
    // previous track's data.
    _clearPerFileState();
    _prop('pause', shouldPlay ? 'no' : 'yes');
    final opts = _buildLoadfileOptions(media.httpHeaders);
    if (opts.isEmpty) {
      _command(['loadfile', resolved.uri, 'replace']);
    } else {
      // Per-Media `httpHeaders` ride along as the 4th `loadfile` arg
      // (mpv 0.38+: index must be `-1` when options are present), so
      // mpv scopes them as file-local for this exact playlist entry —
      // never writing to the global `http-header-fields` option.
      _command(['loadfile', resolved.uri, 'replace', '-1', opts]);
    }
  }

  /// Opens a list of [Media] items as the new playlist, optionally starting at [index].
  ///
  /// Multi-media counterpart of [open]. [index] is clamped to
  /// `[0, medias.length - 1]`. When non-zero the first item is loaded
  /// briefly, then mpv jumps to the requested position.
  Future<void> openAll(List<Media> medias, {bool? play, int index = 0}) async {
    _checkNotDisposed();
    await _ready;
    if (medias.isEmpty) {
      return;
    }
    // Validate the full batch before any side-effect, so a bad header
    // on entry N can't leave entries 0..N-1 half-loaded.
    for (final m in medias) {
      _validateHttpHeaders(m.httpHeaders);
    }
    final clampedIndex = index.clamp(0, medias.length - 1);
    final shouldPlay = play ?? configuration.autoPlay;
    _mediaCache.clear();
    // Gate on the trust-bundle Future so HTTPS items in the playlist
    // see `tls-ca-file` populated by the time `loadfile` fires.
    await _tlsBundleReady;
    // Resolve once per media — content:// resolutions detach a JVM-side
    // FD, doing it twice would leak one FD per track.
    final resolved = <ResolvedUri>[];
    try {
      for (final m in medias) {
        _mediaCache[m.uri] = m;
        final r = await resolveUri(m.uri);
        if (_disposed) {
          await r.dispose?.call();
          for (final prior in resolved) {
            await prior.dispose?.call();
          }
          return;
        }
        _mediaCache[r.uri] = m;
        resolved.add(r);
      }
    } catch (_) {
      // Mid-loop failure: dispose the partially-resolved entries to
      // avoid leaking content:// file descriptors / asset cache files,
      // then rethrow so the caller observes the original error.
      for (final prior in resolved) {
        await prior.dispose?.call();
      }
      rethrow;
    }
    // Per-Media `httpHeaders` ride along as the 4th `loadfile` arg
    // for every entry (initial replace + every append), so mpv scopes
    // them as file-local without ever writing the global
    // `http-header-fields` option.
    _clearPerFileState();
    _prop('pause', shouldPlay ? 'no' : 'yes');
    final firstOpts = _buildLoadfileOptions(medias.first.httpHeaders);
    if (firstOpts.isEmpty) {
      _command(['loadfile', resolved.first.uri, 'replace']);
    } else {
      _command(['loadfile', resolved.first.uri, 'replace', '-1', firstOpts]);
    }
    for (var i = 1; i < medias.length; i++) {
      final opts = _buildLoadfileOptions(medias[i].httpHeaders);
      if (opts.isEmpty) {
        _command(['loadfile', resolved[i].uri, 'append']);
      } else {
        _command(['loadfile', resolved[i].uri, 'append', '-1', opts]);
      }
    }
    if (clampedIndex > 0) {
      _command(['playlist-play-index', clampedIndex.toString()]);
    }
  }

  /// Reads any mpv property as a string.
  ///
  /// **Escape hatch for properties not surfaced by the typed API.** For
  /// observed properties (`volume`, `pause`, `cache-secs`, …), prefer
  /// `player.state.<field>` — the cached value is updated on every
  /// property-change event from mpv and avoids an FFI round-trip.
  ///
  /// Returns `null` if the property doesn't exist or the FFI call
  /// fails. Throws [StateError] if the player has been disposed.
  Future<String?> getRawProperty(String name) async {
    _checkNotDisposed();
    await _ready;
    return using((arena) {
      final n = name.toNativeUtf8(allocator: arena);
      final ptr = _lib.mpvGetPropertyString(_handle, n);
      if (ptr == nullptr) {
        return null;
      }
      final s = ptr.cast<Utf8>().toDartString();
      _lib.mpvFree(ptr.cast());
      return s;
    });
  }

  /// Writes any mpv property as a string.
  ///
  /// **Warning:** this is an escape hatch for properties the typed API
  /// doesn't yet cover. If [name] is one of the registry-observed
  /// properties (volume, pause, cache-*, replaygain*, ao, …), the
  /// resulting state mutation will *also* flow through the property
  /// observer on mpv's side, so `player.state` and `player.stream` will
  /// stay consistent — but expect a one-event-loop-tick delay between
  /// the call returning and the cached state catching up. Prefer the
  /// typed setters (`setVolume`, `setCache`, `setReplayGain`, …) when
  /// they exist, both for type-safety and for synchronous state update.
  ///
  /// `af` is reserved: the typed [AudioEffects] bundle owns it
  /// (including raw passthroughs via [AudioEffects.custom]), and a
  /// raw write would silently desync `state.audioEffects`. Use
  /// [setAudioEffects] / [updateAudioEffects] instead.
  ///
  /// Throws [StateError] if the player has been disposed,
  /// [ArgumentError] if [name] is reserved, or [MpvException] if mpv
  /// rejects the property write (unknown name, out-of-range value, etc.).
  Future<void> setRawProperty(String name, String value) async {
    _checkNotDisposed();
    await _ready;
    if (name == 'af') {
      throw ArgumentError.value(
        name,
        'name',
        'Property `af` is owned by the typed AudioEffects bundle. '
            'Use Player.setAudioEffects / updateAudioEffects, and pass '
            'experimental or expression-based filters via '
            'AudioEffects.custom.',
      );
    }
    _prop(name, value);
  }

  /// Sends a raw mpv command.
  ///
  /// **Escape hatch.** Same caveats as [setRawProperty]: prefer the
  /// typed playback / playlist methods (`play`, `pause`, `seek`,
  /// `add`, `jump`, …) when they cover your use case.
  ///
  /// Throws [StateError] if the player has been disposed, or
  /// [MpvException] if mpv rejects the command (unknown command,
  /// invalid argument, etc.). A successful return guarantees mpv
  /// accepted the command; the actual side-effect on playback state
  /// is observed asynchronously via [Player.stream].
  Future<void> sendRawCommand(List<String> args) async {
    _checkNotDisposed();
    await _ready;
    // Symmetric guard with `setRawProperty('af', ...)`: mpv exposes
    // `af` and `af-command` as commands that mutate the audio chain
    // incrementally — bypassing the typed `AudioEffects` bundle and
    // desynchronizing `state.audioEffects`. The bundle is the single
    // writer of mpv's `af` property; raw incremental mutation goes
    // through `AudioEffects.custom` instead.
    if (args.isNotEmpty && (args.first == 'af' || args.first == 'af-command')) {
      throw ArgumentError.value(
        args.first,
        'args[0]',
        'Command `${args.first}` is owned by the typed AudioEffects bundle. '
            'Use Player.setAudioEffects / updateAudioEffects, and pass '
            'experimental or expression-based filters via AudioEffects.custom.',
      );
    }
    final rc = _command(args);
    if (rc < 0) {
      throw MpvException(
        name: args.isEmpty ? '<empty>' : args.first,
        code: rc,
        message: _errorString(rc),
      );
    }
  }

  /// Pre-filter PCM tap. Subscribers receive [PcmFrame]s captured
  /// **before** the named filter applies its DSP — useful for the
  /// FabFilter Pro-Q-style "input signal" overlay in a per-filter
  /// editor.
  ///
  /// The tap is **lazy**: the engine activates the matching hook in
  /// the audio chain only while at least one listener is attached.
  /// On the last cancel the hook deactivates and the engine reverts
  /// to zero-overhead default. Multiple subscribers to the same
  /// filter share a single underlying tap.
  ///
  /// [filterName] is the libavfilter type name (e.g. `'equalizer'`,
  /// `'acompressor'`). When the same filter type appears multiple
  /// times in the chain, every instance is captured into the same
  /// ring; the wrapper currently does not disambiguate by index.
  ///
  /// Live streams without an active af chain emit no frames. The
  /// stream is silent (no error) when the loaded libmpv does not
  /// expose the filter-tap property.
  Stream<PcmFrame> tapPre(String filterName) =>
      _filterTapPipeline.tapPre(filterName);

  /// Post-filter PCM tap — identical to [tapPre] but captures the
  /// frame **after** the named filter has processed it.
  Stream<PcmFrame> tapPost(String filterName) =>
      _filterTapPipeline.tapPost(filterName);

  @override
  Future<void> dispose() async {
    _cancelHookTimers();
    await super.dispose();
  }
}

/// Base class for [Player] containing shared state and native communication
/// logic.
///
/// Owns:
/// - the FFI handle and event-isolate plumbing,
/// - the [PropertyRegistry] for the ~60 simple mpv properties,
/// - the small set of standalone [ReactiveProperty]s and [StreamController]s
///   that back state fields not directly mirrored by an mpv property
///   (lifecycle: `buffering`/`completed`; complex JSON parses: `playlist`,
///   `metadata`, `audioDevices`, `bufferingPercentage`; pure events: log,
///   error, hook, end-of-file, seek-completed).
abstract class _PlayerBase {
  final PlayerConfiguration configuration;

  late final MpvLibrary _lib;
  late final Pointer<MpvHandle> _handle;
  // Bundled with [_lib] + [_handle] inside a single object so a
  // [Finalizer] can keep a reference and reach the lib even after the
  // player itself is GC'd.
  late final PlayerNativeResources _nativeResources;
  // Eagerly instantiated so `dispose()` is safe even when invoked
  // synchronously after construction. The actual mpv init runs
  // inside the isolate, driven by `_ready`.
  final MpvEventIsolate _eventIsolate = MpvEventIsolate();
  bool _disposed = false;

  // `_activeHookIds` is authoritative for [Player.continueHook]: mpv's
  // behaviour on stale ids is undefined across versions, so duplicate
  // continues are rejected here before they reach FFI.
  // `_registeredHookNames` collapses duplicate registrations per name —
  // mpv allows multiples, but its shutdown path can stall when several
  // events for the same hook are still in flight at quit time.
  final _hookTimeouts = <String, Duration>{};
  final _hookTimers = <int, Timer>{};
  final _activeHookIds = <int>{};
  final _registeredHookNames = <String>{};

  PlayerState _state = const PlayerState();
  final Map<String, Media> _mediaCache = {};

  // ── Property registry (the bulk of state — one spec per mpv property) ──
  late final DefaultPropertyReactives _reactives;
  late final PropertyRegistry _registry;

  // ── Standalone reactive properties (no 1:1 mpv property backing) ───────
  // Lifecycle flags driven by file-boundary events, not by a single property.
  final ReactiveProperty<bool> _buffering = ReactiveProperty<bool>(false);
  final ReactiveProperty<bool> _completed = ReactiveProperty<bool>(false);
  // Derived from JSON properties that need access to player-side context.
  final ReactiveProperty<Playlist> _playlist =
      ReactiveProperty<Playlist>(Playlist.empty);
  final ReactiveProperty<Loop> _loop = ReactiveProperty<Loop>(Loop.off);
  final ReactiveProperty<List<Device>> _audioDevices =
      ReactiveProperty<List<Device>>(
          const [Device(name: 'auto', description: 'Auto')]);
  final ReactiveProperty<Map<String, String>> _metadata =
      ReactiveProperty<Map<String, String>>(const <String, String>{});
  final ReactiveProperty<double> _bufferingPercentage =
      ReactiveProperty<double>(0.0);

  // ── Pure event streams (no current value) ───────────────────────────────
  final StreamController<MpvFileEndedEvent> _endFileCtrl =
      StreamController<MpvFileEndedEvent>.broadcast();
  final StreamController<MpvPlayerError> _errorCtrl =
      StreamController<MpvPlayerError>.broadcast();
  // Log stream from the mpv engine itself (codec / demux / ao / …).
  final StreamController<MpvLogEntry> _logCtrl =
      StreamController<MpvLogEntry>.broadcast();
  // Log stream from the Dart layer itself — JSON parse warnings, hook
  // timeouts, etc. Kept disjoint from `_logCtrl` so library-side noise
  // can be filtered from genuine engine messages without inspecting
  // the prefix.
  final StreamController<MpvLogEntry> _internalLogCtrl =
      StreamController<MpvLogEntry>.broadcast();
  final StreamController<MpvHookEvent> _hookCtrl =
      StreamController<MpvHookEvent>.broadcast();
  final StreamController<void> _seekCompletedCtrl =
      StreamController<void>.broadcast();
  // Nullable payload: each file-loaded transition emits exactly once,
  // with `null` when the new file has no embedded cover. This lets a
  // UI clear / reset on every track change without having to compare
  // against a separate file-transition signal.
  final StreamController<CoverArt?> _coverArtCtrl =
      StreamController<CoverArt?>.broadcast();

  // Real-time FFT + raw PCM pipeline. Lazy: the poll loop starts only
  // when something subscribes to `stream.spectrum` or `stream.pcm`.
  late final SpectrumPipeline _spectrumPipeline;

  // Progressive waveform accumulator, fed off the spectrum pipeline's
  // PCM stream so a single tap drives FFT, raw PCM and waveform.
  late final WaveformPipeline _waveformPipeline;

  // Per-filter pre/post audio tap. Lazy: arms the analyzer-taps
  // property only when at least one [tapPre] / [tapPost] stream has
  // a listener.
  late final FilterTapPipeline _filterTapPipeline;

  PlayerState get state => _state;
  late final PlayerStream stream;

  /// Test-only; `null` outside [Player.testInstrumented].
  final int? _wakeupCounterAddress;

  _PlayerBase({
    this.configuration = const PlayerConfiguration(),
    int? wakeupCounterAddress,
  }) : _wakeupCounterAddress = wakeupCounterAddress {
    // Pure-Dart setup runs on the main isolate (microseconds).
    _reactives = DefaultPropertyReactives();
    _registry = PropertyRegistry()
      ..registerAll(buildDefaultSpecs(
        _reactives,
        onIdleActive: (idle) {
          if (idle) _updateLifecycle(playing: false, buffering: false);
        },
        onAudioOutputState: (state) {
          final err = buildAudioOutputError(state);
          if (err != null) _errorCtrl.add(err);
        },
      ));

    // Streams that don't need _lib/_handle can be wired immediately —
    // a consumer subscribing right after `Player()` sees no events
    // until init completes, which is the correct semantics.
    _fftCtrl = StreamController<FftFrame>.broadcast();
    _pcmStreamCtrl = StreamController<PcmFrame>.broadcast();
    _spectrumCtrl = StreamController<SpectrumSettings>.broadcast();
    _waveformCtrl = StreamController<WaveformData?>.broadcast();
    stream = PlayerStream.fromInternals(
      reactives: _reactives,
      buffering: _buffering,
      completed: _completed,
      playlist: _playlist,
      loop: _loop,
      audioDevices: _audioDevices,
      metadata: _metadata,
      bufferingPercentage: _bufferingPercentage,
      audioEffects: _reactives.audioEffects,
      endFile: _endFileCtrl.stream,
      error: _errorCtrl.stream,
      log: _logCtrl.stream,
      internalLog: _internalLogCtrl.stream,
      hook: _hookCtrl.stream,
      seekCompleted: _seekCompletedCtrl.stream,
      coverArt: _coverArtCtrl.stream,
      fft: _fftCtrl.stream,
      pcm: _pcmStreamCtrl.stream,
      spectrum: _spectrumCtrl.stream,
      waveform: _waveformCtrl.stream,
    );

    // Build the recipe and hand it to the event isolate. All heavy
    // FFI runs there; the main isolate stays free.
    _ready = _bringUpInIsolate();
  }

  /// Test-only — allows tests to await the post-`Player()` init that
  /// now runs in the background isolate. Public methods already
  /// `await _ready` internally so consumers don't normally need this.
  @visibleForTesting
  Future<void> get ready => _ready;

  late final Future<void> _ready;
  bool _bringUpCompleted = false;
  late final StreamController<FftFrame> _fftCtrl;
  late final StreamController<PcmFrame> _pcmStreamCtrl;
  late final StreamController<SpectrumSettings> _spectrumCtrl;
  late final StreamController<WaveformData?> _waveformCtrl;

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
    _filterTapPipeline =
        FilterTapPipeline(lib: _lib, handle: _handle);
    _waveformPipeline.stream.listen(_waveformCtrl.add);

    OrphanHandleTracker.instance.add(_handle);
    _nativeResources = PlayerNativeResources(_lib, _handle);
    playerFinalizer.attach(this, _nativeResources, detach: this);

    // Wire `tls-ca-file` to the bundled CA pem so HTTPS verification
    // works on platforms whose OS trust store the underlying TLS backend
    // cannot read.
    _tlsBundleReady = _autoConfigureTlsCaBundle();
    _bringUpCompleted = true;
  }

  late final Future<void> _tlsBundleReady;

  /// Path of the bundled CA pem extracted to a real filesystem location
  /// by [_autoConfigureTlsCaBundle]. Captured here so [setTlsCaFile]
  /// can restore the default with an empty argument.
  String? _autoTlsCaBundlePath;

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
          (s) => s.copyWith(tlsCaFile: path), _reactives.tlsCaFile, path);
    } catch (e, st) {
      // Surface to the internal-log stream; do NOT throw — the player
      // still works for non-HTTPS streams or for consumers that bring
      // their own CA bundle via `setTlsCaFile`.
      _internalLogCtrl.add(MpvLogEntry(
        level: LogLevel.warn,
        prefix: 'mpv_audio_kit',
        text: 'Failed to auto-configure tls-ca-file: $e\n$st',
      ));
    }
  }

  // --- Core Lifecycle ---

  /// Recipe of pre-init `mpv_set_option_string` calls executed by the
  /// event isolate before `mpv_initialize`.
  Map<String, String> _buildPreInitOptions() => const {
        'vid': 'no',
        'sid': 'no',
        'vo': 'null',
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

  void _handleEvent(MpvIsolateEvent event) {
    // Single fence for every controller add() in this method — dispose()
    // flips `_disposed` before awaiting `_eventSub.cancel()`, so passing
    // this check guarantees every downstream add() lands on an open
    // controller without per-call isClosed checks.
    if (_disposed) return;
    switch (event) {
      case MpvEventStartFile():
        _updateLifecycle(buffering: true, completed: false);
      case MpvEventFileLoaded():
        // `state.playing` is driven by the `core-idle` observer; here we
        // only clear buffering/completed and trigger cover-art capture.
        _updateLifecycle(buffering: false, completed: false);
        _pollPosition();
        _pollChapterState();
        _extractEmbeddedCover();
        if (_bringUpCompleted) _waveformPipeline.reset();
      case MpvEventPlaybackSeek():
        // No-op: mutating position here would flash 0 before the
        // post-restart poll lands.
        break;
      case MpvEventPlaybackRestart():
        _pollPosition();
        _seekCompletedCtrl.add(null);
      case MpvEndFileEvent(:final reason, :final error):
        final typedReason = MpvEndFileReason.fromValue(reason);
        _endFileCtrl.add(MpvFileEndedEvent(
          reason: typedReason,
          error: error,
        ));
        if (error < 0) {
          _errorCtrl.add(MpvEndFileError(
            reason: typedReason,
            code: error,
            message: _errorString(error),
          ));
        }
        final isEof = reason == MpvEndFileReason.eof.value;
        _updateLifecycle(playing: false, buffering: false, completed: isEof);
      case MpvEventShutdown():
        _updateLifecycle(playing: false, buffering: false);
      case MpvEventPropertyDouble(:final name, :final value):
        _dispatchProperty(name, value);
      case MpvEventPropertyInt(:final name, :final value):
        _dispatchProperty(name, value);
      case MpvEventPropertyString(:final name, :final value):
        _dispatchProperty(name, value);
      case MpvEventPropertyNode(:final name, :final value):
        _dispatchProperty(name, value);
      case MpvEventLog(:final prefix, :final level, :final text):
        final typedLevel = LogLevel.fromMpv(level);
        final entry =
            MpvLogEntry(prefix: prefix, level: typedLevel, text: text);
        _logCtrl.add(entry);
        if (typedLevel == LogLevel.error || typedLevel == LogLevel.fatal) {
          _errorCtrl.add(MpvLogError(
            prefix: prefix,
            level: typedLevel,
            text: text,
          ));
        }
      case MpvEventHookFired(:final id, :final name):
        final hook = Hook.fromMpv(name);
        if (hook == null) {
          // Unknown hook name — likely a future mpv build added a new
          // phase. Auto-continue so mpv never stalls, log it on the
          // internal channel for diagnostics.
          _internalLog(
            'Received unknown hook "$name" (id=$id) — auto-continuing. '
            'Update the Hook enum if mpv has added a new lifecycle phase.',
            level: LogLevel.warn,
          );
          _lib.mpvHookContinue(_handle, id);
          return;
        }
        _activeHookIds.add(id);
        final timeout = _hookTimeouts[name];
        if (timeout != null) _startHookTimeout(id, name, timeout);
        _hookCtrl.add(MpvHookEvent(id, hook));
    }
  }

  /// Test-only entry point that exercises the same dispatch pipeline as
  /// the real event isolate. Lets integration tests force a property
  /// transition (e.g. `audio-output-state == failed`) without depending
  /// on the host AO actually reaching that state.
  @visibleForTesting
  void debugDispatchProperty(String name, dynamic raw) =>
      _dispatchProperty(name, raw);

  /// Routes a property-change to the registry first, then falls back to the
  /// custom handlers for properties whose update logic doesn't fit a simple
  /// (parser, reducer) pair (JSON parsing with player-side context, derived
  /// fields aggregating multiple mpv properties, etc.).
  void _dispatchProperty(String name, dynamic raw) {
    final next = _registry.dispatch(name, raw, _state);
    if (next != null) {
      _state = next;
      return;
    }
    if (_registry.specFor(name) != null) {
      // Spec exists but value was deduplicated — nothing to do.
      return;
    }
    // Custom out-of-registry handlers for the few properties whose update
    // logic touches more than `(parse → reduce)` (player-side context like
    // `_mediaCache`, `_state.playlist`, `_state.cache.secs`, or the
    // two-property aggregation behind `loop`).
    switch (name) {
      case 'loop-file':
      case 'loop-playlist':
        _updateLoopFromMpv(name, raw as String);
      case 'playlist':
        _updatePlaylistFromNode(raw);
      case 'audio-device':
        _updateActiveAudioDevice(raw as String);
      case 'audio-device-list':
        _updateDevicesFromNode(raw);
      case 'metadata':
        _updateMetadataFromNode(raw);
      case 'demuxer-cache-state':
        _updateBufferingPercentageFromNode(raw);
    }
  }

  // --- Low Level Native Bridge ---

  /// Writes a property and throws [MpvException] on rejection.
  ///
  /// All typed setters (setVolume, setRate, setAudioEffects, …) flow
  /// through this method. Errors are surfaced rather than swallowed so
  /// the caller can react (out-of-range value, unknown name, malformed
  /// `af` chain after `AudioEffects.custom`, etc.). `_propRc` is the
  /// rc-returning variant for the few call sites that need to tolerate
  /// failures explicitly.
  void _prop(String name, String value) {
    final rc = _propRc(name, value);
    if (rc < 0) {
      throw MpvException(name: name, code: rc, message: _errorString(rc));
    }
  }

  int _propRc(String name, String value) {
    return using((arena) => _lib.mpvSetPropertyString(
        _handle,
        name.toNativeUtf8(allocator: arena),
        value.toNativeUtf8(allocator: arena)));
  }

  int _command(List<String> args) {
    return using((arena) {
      final arr = arena<Pointer<Utf8>>(args.length + 1);
      for (var i = 0; i < args.length; i++) {
        arr[i] = args[i].toNativeUtf8(allocator: arena);
      }
      arr[args.length] = nullptr;
      return _lib.mpvCommand(_handle, arr);
    });
  }

  String _errorString(int code) {
    final p = _lib.mpvErrorString(code);
    return p == nullptr ? 'error $code' : p.cast<Utf8>().toDartString();
  }

  void _startHookTimeout(int id, String name, Duration timeout) {
    _hookTimers[id] = Timer(timeout, () {
      _hookTimers.remove(id);
      // The active-id set is the source of truth: if a manual
      // continueHook beat us to it, the id is gone and we skip the
      // redundant FFI call.
      if (!_activeHookIds.remove(id)) return;
      _internalLog(
        'Hook "$name" (id=$id) timed out after ${timeout.inSeconds}s — '
        'auto-continuing to unblock mpv',
        level: LogLevel.warn,
      );
      if (!_disposed) _lib.mpvHookContinue(_handle, id);
    });
  }

  void _cancelHookTimers() {
    for (final timer in _hookTimers.values) {
      timer.cancel();
    }
    _hookTimers.clear();
    // Continue every still-active hook on mpv's side BEFORE we drop
    // them from the active set. Without this, mpv blocks on the
    // pending hooks during its shutdown path: `dispose()` issues
    // `quit`, mpv tries to drain the hook queue first, and never
    // fires MPV_EVENT_SHUTDOWN — so the event isolate never exits.
    // `_cancelHookTimers` is called from dispose BEFORE `_disposed`
    // is flipped, so the handle is still valid here.
    for (final id in _activeHookIds) {
      _lib.mpvHookContinue(_handle, id);
    }
    _activeHookIds.clear();
  }

  /// Builds the `loadfile` `<options>` argument from a [Media]'s
  /// `httpHeaders`. The `%N%` length prefix only escapes the outer
  /// option-list parser, not mpv's inner stringlist split — hence
  /// the per-key/value rejection of CR, LF, `,`, NUL (and `:` in
  /// keys) by [_validateHeaderKey] / [_validateHeaderValue].
  String _buildLoadfileOptions(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return '';
    for (final e in headers.entries) {
      _validateHeaderKey(e.key);
      _validateHeaderValue(e.value);
    }
    final joined = headers.entries.map((e) => '${e.key}: ${e.value}').join(',');
    final bytes = utf8.encode(joined).length;
    return 'http-header-fields=%$bytes%$joined';
  }

  static final RegExp _kForbiddenInHeaderKey = RegExp(r'[\r\n,:\x00]');
  static final RegExp _kForbiddenInHeaderValue = RegExp(r'[\r\n,\x00]');

  /// Up-front validator called by every load entry point before
  /// `resolveUri` runs.
  void _validateHttpHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return;
    for (final e in headers.entries) {
      _validateHeaderKey(e.key);
      _validateHeaderValue(e.value);
    }
  }

  void _validateHeaderKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'header name', 'must not be empty');
    }
    if (_kForbiddenInHeaderKey.hasMatch(key)) {
      throw ArgumentError.value(
          key, 'header name', 'must not contain CR, LF, NUL, comma, or colon');
    }
  }

  void _validateHeaderValue(String value) {
    if (_kForbiddenInHeaderValue.hasMatch(value)) {
      throw ArgumentError.value(value, 'header value',
          'must not contain CR, LF, NUL, or comma (would split or inject the HTTP request)');
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Player has been disposed');
    }
  }

  /// Rejects NaN / +Inf / -Inf before they reach `toStringAsFixed`,
  /// which would emit the literal `'NaN'` / `'Infinity'` and have mpv
  /// reject the property write at the FFI boundary. Catching it on the
  /// wrapper side gives the caller a precise [ArgumentError] naming the
  /// parameter, instead of an opaque [MpvException] from libmpv.
  void _checkFinite(double value, String paramName) {
    if (!value.isFinite) {
      throw ArgumentError.value(
          value, paramName, 'Expected a finite double (got NaN/Infinity)');
    }
  }

  // --- Internal State Pipeline ---

  /// Optimistic state update used by every typed setter after pushing
  /// a value to mpv. Writes [value] into [reactive] (which dedups, so
  /// equal writes are silent on the stream) and folds it into [_state]
  /// via [updater]. Short-circuits on dedup to skip a redundant
  /// [PlayerState] allocation.
  void _updateField<T>(
    PlayerState Function(PlayerState) updater,
    ReactiveProperty<T> reactive,
    T value,
  ) {
    if (!reactive.update(value)) return;
    _state = updater(_state);
  }

  /// Clears the per-track fields a consumer is likely to read
  /// synchronously on a track-change boundary (the public open()
  /// path returns before the new file's MPV_EVENT_FILE_LOADED
  /// fires).
  ///
  /// Restricted to fields where mpv re-emits the new value reliably
  /// after the load. mpv's own observer (see
  /// `player/client.c::send_client_property_changes`) dedupes on
  /// `equal_mpv_value(prop->value, val)`, so any property whose new
  /// value happens to match the previously-observed value (same
  /// `duration` across two tracks; same `embedded-cover-art-data`
  /// for same-album files; same `chapter-list`) would NOT fire
  /// PROPERTY_CHANGE. Wrapper-side reset to defaults on those would
  /// strand the cell at the default until the next genuinely-new
  /// value arrives. `position` is safe because `time-pos` re-emits
  /// at ~30Hz during playback. The remaining fields are handled by
  /// custom paths that do not depend on mpv's observer dedup.
  void _clearPerFileState() {
    final r = _reactives;
    r.position.update(Duration.zero);
    r.currentChapter.update(null);
    r.chapters.update(const <Chapter>[]);
    _state = _state.copyWith(
      position: Duration.zero,
      coverArt: null,
      currentChapter: null,
      chapters: const <Chapter>[],
    );
    _coverArtCtrl.add(null);
  }

  /// Updates the lifecycle triple (playing/buffering/completed) and
  /// emits per-reactive only for fields that actually changed. Used
  /// for compound transitions (start-file, file-loaded, end-file,
  /// shutdown, idle-active). The pure diff lives in [computeLifecycle].
  void _updateLifecycle({bool? playing, bool? buffering, bool? completed}) {
    final result = computeLifecycle(
      prev: _state,
      playing: playing,
      buffering: buffering,
      completed: completed,
    );
    _state = result.newState;
    if (result.playingDidChange) _reactives.playing.update(playing!);
    if (result.bufferingDidChange) _buffering.update(buffering!);
    if (result.completedDidChange) _completed.update(completed!);
  }

  // --- Custom property handlers (JSON / derived) ---

  void _updateLoopFromMpv(String name, String value) {
    final next = deriveLoop(name, value, _state.loop);
    if (next == null) return;
    _updateField(
      (s) => s.copyWith(loop: next),
      _loop,
      next,
    );
  }

  void _updatePlaylistFromNode(dynamic raw) {
    try {
      final playlist = parsePlaylistNode(
        raw: raw,
        mediaCache: _mediaCache,
        previous: _state.playlist,
      );
      _updateField((s) => s.copyWith(playlist: playlist), _playlist, playlist);
    } catch (e) {
      _internalLog('Failed to parse playlist: $e', level: LogLevel.warn);
    }
  }

  void _updateActiveAudioDevice(String name) {
    // mpv only echoes the device name back on `audio-device`. Recover
    // the proper description by looking it up in the parsed
    // `audio-device-list` (state.audioDevices). Falls back to the name
    // on cache miss — typical at boot, before the list arrives.
    final list = _state.audioDevices;
    String description = name;
    for (final d in list) {
      if (d.name == name) {
        description = d.description;
        break;
      }
    }
    final device = Device(name: name, description: description);
    _updateField(
      (s) => s.copyWith(audioDevice: device),
      _reactives.audioDevice,
      device,
    );
  }

  void _updateDevicesFromNode(dynamic raw) {
    try {
      final devices = parseDeviceListNode(raw);
      _updateField(
          (s) => s.copyWith(audioDevices: devices), _audioDevices, devices);
    } catch (e) {
      _internalLog('Failed to parse audio devices: $e', level: LogLevel.warn);
    }
  }

  void _updateMetadataFromNode(dynamic raw) {
    try {
      final metadata = parseMetadataNode(raw);
      if (metadata == null) return;
      _updateField((s) => s.copyWith(metadata: metadata), _metadata, metadata);
    } catch (e) {
      _internalLog('Failed to parse metadata: $e', level: LogLevel.warn);
    }
  }

  void _updateBufferingPercentageFromNode(dynamic raw) {
    try {
      final pct = parseDemuxerCacheStateNode(raw, _state.cache.secs);
      _updateField((s) => s.copyWith(bufferingPercentage: pct),
          _bufferingPercentage, pct);
    } catch (e) {
      _internalLog('Failed to parse cache state: $e', level: LogLevel.warn);
    }
  }

  // --- Misc helpers ---

  void _pollPosition() {
    if (_disposed) return;
    using((arena) {
      final n = 'time-pos'.toNativeUtf8(allocator: arena);
      final buf = arena<Double>();
      final rc = _lib.mpvGetProperty(
          _handle, n, MpvFormat.mpvFormatDouble, buf.cast());
      if (rc == MpvError.mpvErrorSuccess) {
        final pos = Duration(microseconds: (buf.value * 1e6).round());
        _updateField(
            (s) => s.copyWith(position: pos), _reactives.position, pos);
      }
    });
  }

  /// Force-refreshes [PlayerState.chapters] and
  /// [PlayerState.currentChapter] by reading the underlying mpv
  /// properties directly. mpv's observer queue dedupes on
  /// `equal_mpv_value` (see `player/client.c::send_client_property_changes`),
  /// so two consecutive tracks with structurally-equal `chapter-list`
  /// (e.g. an audiobook where consecutive parts share the same chapter
  /// pattern) would skip the PROPERTY_CHANGE event and strand the
  /// wrapper at whatever the previous file left behind. Polling on
  /// FILE_LOADED bypasses the dedup so the wrapper always carries the
  /// truth for the current file.
  void _pollChapterState() {
    if (_disposed) return;
    // chapter index — INT64 scalar.
    using((arena) {
      final n = 'chapter'.toNativeUtf8(allocator: arena);
      final buf = arena<Int64>();
      final rc =
          _lib.mpvGetProperty(_handle, n, MpvFormat.mpvFormatInt64, buf.cast());
      if (rc == MpvError.mpvErrorSuccess) {
        // mpv exposes -1 / -2 etc. as "no chapter active"; surface as null.
        final idx = buf.value < 0 ? null : buf.value.toInt();
        _updateField((s) => s.copyWith(currentChapter: idx),
            _reactives.currentChapter, idx);
      }
    });
    // chapter-list — NODE_ARRAY. Allocate, read, decode, dispatch
    // through the registry (re-using the parser), free the node tree.
    using((arena) {
      final n = 'chapter-list'.toNativeUtf8(allocator: arena);
      final nodePtr = arena<MpvNode>();
      final rc = _lib.mpvGetProperty(
          _handle, n, MpvFormat.mpvFormatNode, nodePtr.cast());
      if (rc == MpvError.mpvErrorSuccess) {
        final decoded = decodeMpvNode(nodePtr.ref);
        try {
          _dispatchProperty('chapter-list', decoded);
        } finally {
          _lib.mpvFreeNodeContents(nodePtr);
        }
      }
    });
  }

  /// Internal log helper — emits on the library-side log channel
  /// ([PlayerStream.internalLog]), kept separate from mpv's engine log
  /// stream ([PlayerStream.log]).
  void _internalLog(String message, {LogLevel level = LogLevel.info}) =>
      _internalLogCtrl.add(
          MpvLogEntry(prefix: 'mpv_audio_kit', level: level, text: message));

  void _extractEmbeddedCover() {
    if (_disposed) return;
    // Emit unconditionally — `null` signals "no cover on the new
    // file" so subscribers can clear stale artwork on track changes.
    final cover = CoverArtExtractor.capture(_lib, _handle);
    _state = _state.copyWith(coverArt: cover);
    _coverArtCtrl.add(cover);
  }

  /// Tears down the player.
  ///
  /// The teardown order is load-bearing. The sequence is:
  ///
  /// 1. **Flip `_disposed`** so any subsequent setter / public-API call
  ///    fails fast via `_checkNotDisposed()`.
  /// 2. **Drop the [OrphanHandleTracker] entry** so a hot-restart that
  ///    fires before the destroy completes doesn't try to clean up a
  ///    handle we're already cleaning up.
  /// 3. **Await `_eventSub.cancel()`** so no further `_handleEvent`
  ///    invocations land after this point.
  /// 4. **Send the `quit` command** to mpv. mpv processes it
  ///    asynchronously and fires `MPV_EVENT_SHUTDOWN` inside its own
  ///    event queue, which unblocks the isolate's `mpv_wait_event`
  ///    on the next iteration.
  /// 5. **Await `_eventIsolate.stop()`**: waits for the isolate to
  ///    actually exit (the `quit`-driven `MPV_EVENT_SHUTDOWN` lets the
  ///    run-loop unwind naturally).
  /// 6. **`mpvTerminateDestroy(_handle)`** AFTER the isolate is gone.
  ///    Calling destroy while the isolate is still inside
  ///    `mpv_wait_event` would race the event-loop thread and crash
  ///    libmpv when the handle is freed mid-syscall.
  /// 7. **Close all reactive properties + controllers**. Order within
  ///    this group does not matter for correctness (they tolerate
  ///    `close()` while a listener is attached); grouping by ownership
  ///    is for auditability.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    // Wait for init to settle. The handle / lib / native-resources
    // fields are only assigned when bring-up reaches the very end of
    // its body, so `_bringUpCompleted` is the authoritative gate for
    // touching them — even if `_ready` resolved without throwing it
    // may have early-returned because dispose flipped during init.
    try {
      await _ready;
    } catch (_) {}

    if (_bringUpCompleted) {
      _nativeResources.disposed = true;
      playerFinalizer.detach(this);
      OrphanHandleTracker.instance.remove(_handle);
      await _filterTapPipeline.dispose();
      await _waveformPipeline.dispose();
      await _spectrumPipeline.dispose();
      // Cooperative quit: mpv fires MPV_EVENT_SHUTDOWN, the isolate's
      // mpv_wait_event returns, and the loop unwinds naturally. Calling
      // mpv_terminate_destroy here would race the isolate and crash
      // libmpv when the handle is freed mid-syscall.
      _command(['quit']);
      await _eventIsolate.stop();
      _lib.mpvTerminateDestroy(_handle);
    } else {
      // Init failed; the isolate may or may not be alive. Best effort.
      try {
        await _eventIsolate.stop();
      } catch (_) {}
    }

    // Close registry-backed reactives, then standalone ones, then
    // pure-event controllers. Order is for auditability — close() is
    // safe with attached listeners.
    await _registry.closeAll();
    await Future.wait<void>([
      _buffering.close(),
      _completed.close(),
      _playlist.close(),
      _loop.close(),
      _audioDevices.close(),
      _metadata.close(),
      _bufferingPercentage.close(),
    ]);
    await Future.wait<void>([
      _endFileCtrl.close(),
      _errorCtrl.close(),
      _logCtrl.close(),
      _internalLogCtrl.close(),
      _hookCtrl.close(),
      _seekCompletedCtrl.close(),
      _coverArtCtrl.close(),
    ]);
  }
}
