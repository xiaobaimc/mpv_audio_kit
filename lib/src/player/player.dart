// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../dsp/filter_tap_pipeline.dart';
import '../dsp/spectrum_pipeline.dart';
import '../dsp/waveform_pipeline.dart';
import '../events/mpv_exception.dart';
import '../events/mpv_hook_event.dart';
import '../events/mpv_log_entry.dart';
import '../events/mpv_player_error.dart';
import '../generated/audio_effects_settings.dart';
import '../internals/cover_art_extractor.dart';
import '../internals/duration_seconds.dart';
import '../internals/event_isolate.dart';
import '../internals/library_loader.dart';
import '../internals/orphan_handle_tracker.dart';
import '../internals/player_finalizer.dart';
import '../internals/tls_ca_bundle.dart';
import '../internals/uri_resolver.dart';
import '../media_session/media_session_controller.dart';
import '../media_session/media_session_inputs.dart';
import '../models/chapter.dart';
import '../models/cover_art.dart';
import '../models/demuxer_cache_state.dart';
import '../models/device.dart';
import '../models/fft_frame.dart';
import '../models/media.dart';
import '../models/media_session.dart';
import '../models/pcm_frame.dart';
import '../models/playlist.dart';
import '../models/waveform_data.dart';
import '../mpv_bindings.dart' hide MpvEndFileReason;
import '../reactive/default_reactives.dart';
import '../reactive/default_specs.dart';
import '../reactive/node_parsers.dart';
import '../reactive/property_registry.dart';
import '../reactive/reactive_property.dart';
import '../types/enums/cover.dart';
import '../types/enums/format.dart';
import '../types/enums/gapless.dart';
import '../types/enums/hook.dart';
import '../types/enums/log_level.dart';
import '../types/enums/loop.dart';
import '../types/enums/spdif.dart';
import '../types/enums/tap_side.dart';
import '../types/sealed/channels.dart';
import '../types/sealed/media_session_command.dart';
import '../types/sealed/track.dart';
import '../types/settings/cache_settings.dart';
import '../types/settings/replay_gain_settings.dart';
import '../types/settings/spectrum_settings.dart';
import 'audio_output_error.dart';
import 'lifecycle_transitions.dart';
import 'player_api.dart';
import 'player_configuration.dart';
import 'player_state.dart';
import 'player_stream.dart';

export '../events/mpv_hook_event.dart';
export '../events/mpv_log_entry.dart';
export '../generated/audio_effects.dart';
export '../generated/audio_effects_settings.dart';
export '../models/audio_params.dart';
export '../models/cover_art.dart';
export '../models/device.dart';
export '../models/media.dart';
export '../models/media_session.dart';
export '../models/playlist.dart';
export '../types/enums/format.dart';
export '../types/enums/interruption_policy.dart';
export '../types/enums/loop.dart';
export '../types/enums/media_action.dart';
export '../types/sealed/channels.dart';
export '../types/sealed/media_session_artwork.dart';
export '../types/sealed/media_session_command.dart';
export '../types/sealed/track.dart';
export '../types/settings/spectrum_settings.dart';
export 'player_configuration.dart';
export 'player_state.dart';
export 'player_stream.dart';

part 'mixins/player_audio.part.dart';
part 'mixins/player_dispatch.part.dart';
part 'mixins/player_ffi.part.dart';
part 'mixins/player_hooks.part.dart';
part 'mixins/player_init.part.dart';
part 'mixins/player_load_validation.part.dart';
part 'mixins/player_media_session.part.dart';
part 'mixins/player_network.part.dart';
part 'mixins/player_playback.part.dart';
part 'mixins/player_playlist.part.dart';

/// A high-performance audio player powered by libmpv.
///
/// Implements [PlayerApi] so test code can mock the player without
/// dragging in the FFI handle and event isolate
/// (`class MockPlayer extends Mock implements PlayerApi {}`).
class Player extends _PlayerBase
    with
        _FfiModule,
        _LoadValidationModule,
        _InitModule,
        _DispatchModule,
        _PlaybackModule,
        _PlaylistModule,
        _AudioModule,
        _NetworkModule,
        _HooksModule,
        _MediaSessionModule
    implements PlayerApi {
  /// Creates a [Player] instance with optional [configuration].
  Player({super.configuration});

  /// Process-wide single-instance guard for the OS media session.
  /// SMTC (Windows) and MPNowPlayingInfoCenter (Apple) are
  /// single-instance per process — enabling on a second [Player]
  /// would silently steal the first one's lockscreen entry. Linux
  /// MPRIS could support multiple instances via `instance<PID>`
  /// suffixing, but we ban it universally for cross-OS consistency.
  /// Cleared on `dispose()` and on `setMediaSession(null)`.
  static Player? _mediaSessionOwner;

  /// Test-only. The event isolate writes to [wakeupCounterAddress] on
  /// every wakeup — a bogus value corrupts process memory.
  @visibleForTesting
  Player.testInstrumented({
    super.configuration,
    required int super.wakeupCounterAddress,
  });

  // --- Public Specialized API ---

  /// Opens a [Media] and optionally starts playback immediately.
  ///
  /// `pause` is set as a global property before `loadfile` so the
  /// property observer always fires on the first-load transition
  /// (a per-file option can skip the `PROPERTY_CHANGE` emit).
  /// Rapid back-to-back `open()` calls don't race: `loadfile replace`
  /// aborts the previous load, so the last `(pause, loadfile)` pair wins.
  @override
  Future<void> open(Media media, {bool? play}) async {
    _checkNotDisposed();
    await _ready;
    _validateLoadOptions(media);
    final shouldPlay = play ?? configuration.autoPlay;
    // Optimistic intent (the play/pause axis), written at the call point —
    // BEFORE the `resolveUri` / trust-bundle awaits below — so a play() /
    // pause() issued right after open() (without awaiting it) wins by call
    // order instead of racing this write past the I/O hops. mpv leaves
    // `pause` at `no` and fires no PROPERTY_CHANGE on the first autoplay
    // load, so the observer alone would never surface this intent.
    _updateField(
      (s) => s.copyWith(playWhenReady: shouldPlay),
      _reactives.playWhenReady,
      shouldPlay,
    );
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
    // Drop visible per-track state synchronously — cover art, chapter
    // list and current chapter index — so a UI that reads the state
    // immediately after `open()` returns doesn't briefly render the
    // previous track's data.
    _clearPerFileState();
    _prop('pause', shouldPlay ? 'no' : 'yes');
    final opts = _buildLoadfileOptions(media);
    if (opts.isEmpty) {
      _command(['loadfile', resolved.uri, 'replace']);
    } else {
      // Per-Media `httpHeaders` / `httpChunkSize` ride along as the 4th
      // `loadfile` arg (mpv 0.38+: index must be `-1` when options are
      // present), so mpv scopes them as file-local for this exact playlist
      // entry — never writing the global `http-header-fields` / `stream-lavf-o`.
      _command(['loadfile', resolved.uri, 'replace', '-1', opts]);
    }
  }

  /// Opens a list of [Media] items as the new playlist, optionally starting at [index].
  ///
  /// Multi-media counterpart of [open]. [index] is clamped to
  /// `[0, medias.length - 1]`. When non-zero the first item is loaded
  /// briefly, then mpv jumps to the requested position.
  @override
  Future<void> openAll(List<Media> medias, {bool? play, int index = 0}) async {
    _checkNotDisposed();
    await _ready;
    if (medias.isEmpty) {
      return;
    }
    // Validate the full batch before any side-effect, so a bad header
    // on entry N can't leave entries 0..N-1 half-loaded.
    for (final m in medias) {
      _validateLoadOptions(m);
    }
    final clampedIndex = index.clamp(0, medias.length - 1);
    final shouldPlay = play ?? configuration.autoPlay;
    // Optimistic intent written at the call point, before the resolve / tls
    // awaits below — see [open] for the rationale.
    _updateField(
      (s) => s.copyWith(playWhenReady: shouldPlay),
      _reactives.playWhenReady,
      shouldPlay,
    );
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
    final firstOpts = _buildLoadfileOptions(medias.first);
    if (firstOpts.isEmpty) {
      _command(['loadfile', resolved.first.uri, 'replace']);
    } else {
      _command(['loadfile', resolved.first.uri, 'replace', '-1', firstOpts]);
    }
    for (var i = 1; i < medias.length; i++) {
      final opts = _buildLoadfileOptions(medias[i]);
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

  /// Loads a playlist FILE or URL (`.m3u` / `.m3u8` / `.pls` / `.cue`) and
  /// optionally starts playback. Unlike [open] — which loads [playlist] as a
  /// single entry — this parses it with mpv's `loadlist`, so its entries
  /// become the playlist. This is the path for internet-radio station lists
  /// and remote `.m3u` playlists.
  ///
  /// [PlayerStream.playlist] / [PlayerState.playlist] reflect the parsed
  /// entries once mpv expands them. When [play] is null the configuration's
  /// autoplay value decides. Replaces any currently loaded file or playlist.
  ///
  /// Per-[Media] options (`httpHeaders`, `demuxerLavfOptions`, `httpChunkSize`)
  /// are validated but NOT applied to the playlist fetch — `loadlist` has no
  /// file-local options slot. Entries parsed out of the playlist inherit the
  /// global network/demuxer settings.
  @override
  Future<void> openPlaylistFile(Media playlist, {bool? play}) async {
    _checkNotDisposed();
    await _ready;
    _validateLoadOptions(playlist);
    final shouldPlay = play ?? configuration.autoPlay;
    // Optimistic intent written at the call point — same rationale as [open].
    _updateField(
      (s) => s.copyWith(playWhenReady: shouldPlay),
      _reactives.playWhenReady,
      shouldPlay,
    );
    _mediaCache.clear();
    final tls = _tlsBundleReady;
    final resolved = await resolveUri(playlist.uri);
    await tls;
    if (_disposed) {
      await resolved.dispose?.call();
      return;
    }
    _clearPerFileState();
    _prop('pause', shouldPlay ? 'no' : 'yes');
    _command(['loadlist', resolved.uri, 'replace']);
  }

  @override
  Future<void> dispose() async {
    // Release the OS media session BEFORE tearing libmpv down. After
    // super.dispose() the FFI handle is gone — leaving the native
    // session published would surface a stale lockscreen entry
    // pointing at a dead Player, and incoming commands (play from
    // the lockscreen) would land on disposed state.
    if (identical(Player._mediaSessionOwner, this)) {
      try {
        await setMediaSession(null);
      } catch (_) {
        // Best effort — session teardown must never block disposal.
      }
    }
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

  // Latched true on the first MPV_EVENT_START_FILE. Gates the idle-active
  // intent reset: the initial observe burst delivers `idle-active=true`
  // (the player starts idle) BEFORE any file load is attempted, and that
  // stale value must not clear a `playWhenReady` intent set by an
  // open(play: true) that is still settling. Port delivery is FIFO, so the
  // startup idle-active always precedes the first START_FILE. Latching on
  // START_FILE (which fires even for a load that fails to open) rather than
  // FILE_LOADED means a failed first open() still arms the reset, so its
  // intent doesn't stick true.
  bool _hasLoadedFile = false;

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
    const [Device(name: 'auto', description: 'Auto')],
  );
  final ReactiveProperty<Map<String, String>> _metadata =
      ReactiveProperty<Map<String, String>>(const <String, String>{});
  final ReactiveProperty<double> _bufferingPercentage =
      ReactiveProperty<double>(0.0);
  final ReactiveProperty<DemuxerCacheState> _demuxerCacheState =
      ReactiveProperty<DemuxerCacheState>(DemuxerCacheState.empty);
  // OS media-session config + metadata override. Null = disabled.
  // Updated synchronously by [_MediaSessionModule.setMediaSession].
  final ReactiveProperty<MediaSession?> _mediaSession =
      ReactiveProperty<MediaSession?>(null);

  // Dart-side orchestrator that ferries state from `PlayerStream` to
  // the native media-session channel and routes inbound OS commands
  // back. Null while the session is disabled; lazily allocated on
  // first `setMediaSession(non-null)` and torn down on disable or
  // on `dispose()`.
  MediaSessionController? _mediaSessionController;

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
  // Incoming commands from the OS media session (lockscreen, BT
  // headset, Siri / Assistant), routed back from the per-platform
  // native implementation.
  final StreamController<MediaSessionCommand> _mediaSessionCommandsCtrl =
      StreamController<MediaSessionCommand>.broadcast();

  // Real-time FFT + raw PCM pipeline. Lazy: the poll loop starts only
  // when something subscribes to `stream.spectrum` or `stream.pcm`.
  late final SpectrumPipeline _spectrumPipeline;

  // Static waveform analyzer. Listener-gated: arms the native
  // analyzer and polls only while `stream.waveform` has a listener.
  late final WaveformPipeline _waveformPipeline;

  // Per-filter pre/post audio tap. Lazy: arms the analyzer-taps
  // property only when at least one [PlayerStream.tap] stream has a
  // listener.
  late final FilterTapPipeline _filterTapPipeline;

  PlayerState get state => _state;
  late final PlayerStream stream;

  /// Test-only; `null` outside [Player.testInstrumented].
  final int? _wakeupCounterAddress;

  // ── Cross-mixin surface ──────────────────────────────────────────────────
  // These members live in the `.part` mixins below but are declared here
  // (abstract) so `_PlayerBase`'s constructor / `dispose` and the sibling
  // domain mixins can call across part boundaries — `on _PlayerBase` only
  // exposes what `_PlayerBase` itself declares.

  /// See `_FfiModule` (player_ffi.part.dart).
  void _prop(String name, String value);
  int _propRc(String name, String value);
  int _command(List<String> args);
  int _setChapterListNode(List<Chapter> chapters);
  String _errorString(int code);

  /// See `_LoadValidationModule` (player_load_validation.part.dart).
  String _buildLoadfileOptions(Media media);
  void _validateLoadOptions(Media media);

  /// See `_InitModule` (player_init.part.dart) — called by the constructor.
  Future<void> _bringUpInIsolate();

  /// See `_DispatchModule` (player_dispatch.part.dart) — wired as the event
  /// isolate's `onEvent` during bring-up.
  void _handleEvent(MpvIsolateEvent event);

  /// See `_DispatchModule` — `setAudioDevice` reuses it to optimistically
  /// resolve the device description from the parsed `audio-device-list`.
  void _updateActiveAudioDevice(String name);

  _PlayerBase({
    this.configuration = const PlayerConfiguration(),
    int? wakeupCounterAddress,
  }) : _wakeupCounterAddress = wakeupCounterAddress {
    // Pure-Dart setup runs on the main isolate (microseconds).
    _reactives = DefaultPropertyReactives();
    _registry = PropertyRegistry()
      ..registerAll(
        buildDefaultSpecs(
          _reactives,
          onIdleActive: (idle) {
            if (idle) {
              _updateLifecycle(playing: false, buffering: false);
              // mpv has entered its idle loop (nothing loaded) → the
              // play/pause intent is spent; settle the OS button on "play".
              // Gated on [_hasLoadedFile] so the startup idle-active burst
              // can't clear a fresh open(play: true) intent. mpv reaches idle
              // after a `stop`, or after a load that ends with no next entry
              // and is NOT held by keep-open (e.g. a failed first open). The
              // natural end of playable content under the shipped
              // `keep-open: yes` does NOT fire idle-active — that path is
              // handled by [onEofReached] instead. A mid-playlist advance
              // also doesn't fire idle-active, so this never flickers.
              if (_hasLoadedFile) {
                _updateField(
                  (s) => s.copyWith(playWhenReady: false),
                  _reactives.playWhenReady,
                  false,
                );
              }
            }
          },
          onAudioOutputState: (state) {
            final err = buildAudioOutputError(state);
            if (err != null) _errorCtrl.add(err);
          },
          onEofReached: (eof) {
            // `keep-open: yes` (shipped pre-init option) makes mpv park
            // paused on the last frame at end-of-content and withhold BOTH
            // MPV_EVENT_END_FILE and idle-active, so the two writers that
            // normally settle the transport (the EndFile completed flag and
            // the idle-active intent reset) never fire for a single track or
            // the last playlist entry. The `eof-reached` rising edge is the
            // signal that DOES fire there.
            if (!_hasLoadedFile) return;
            if (eof) {
              // Only at the GENUINE end of content — not a gapless
              // mid-playlist boundary (where eof-reached can blip) and not
              // while looping (where the file/playlist restarts). Otherwise
              // the OS play/pause button would flicker.
              if (_isEndOfContent()) {
                _updateLifecycle(completed: true);
                _updateField(
                  (s) => s.copyWith(playWhenReady: false),
                  _reactives.playWhenReady,
                  false,
                );
              }
            } else if (_state.completed) {
              // Left the end (a seek back into the track, or a new file):
              // the track is no longer completed.
              _updateLifecycle(completed: false);
            }
          },
        ),
      );

    // Streams that don't need _lib/_handle can be wired immediately —
    // a consumer subscribing right after `Player()` sees no events
    // until init completes, which is the correct semantics.
    _fftCtrl = StreamController<FftFrame>.broadcast();
    _pcmStreamCtrl = StreamController<PcmFrame>.broadcast();
    _spectrumCtrl = StreamController<SpectrumSettings>.broadcast();
    // Listener-gated: the native waveform analyzer arms only while a
    // consumer is subscribed. The pipeline is built during isolate
    // bring-up; a subscriber that lands before then is reconciled
    // once bring-up finishes (see `_bringUpInIsolate`).
    _waveformCtrl = StreamController<WaveformData?>.broadcast(
      onListen: () {
        if (_bringUpCompleted) _waveformPipeline.setEnabled(true);
      },
      onCancel: () {
        if (_bringUpCompleted) _waveformPipeline.setEnabled(false);
      },
    );
    stream = PlayerStream.fromInternals(
      reactives: _reactives,
      buffering: _buffering,
      completed: _completed,
      playlist: _playlist,
      loop: _loop,
      audioDevices: _audioDevices,
      metadata: _metadata,
      bufferingPercentage: _bufferingPercentage,
      demuxerCacheState: _demuxerCacheState,
      audioEffects: _reactives.audioEffects,
      mediaSession: _mediaSession,
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
      tap: (filter, {required side}) => switch (side) {
        TapSide.pre => _filterTapPipeline.tapPre(filter.filterName),
        TapSide.post => _filterTapPipeline.tapPost(filter.filterName),
      },
      mediaSessionCommands: _mediaSessionCommandsCtrl.stream,
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

  /// Last playlist-entry `path` the waveform pipeline was reset for. Lets the
  /// FILE_LOADED handler skip the redundant reset mpv fires on internal
  /// reloads of the same source (see the dedup in `_handleEvent`).
  String? _lastWaveformSource;
  late final StreamController<FftFrame> _fftCtrl;
  late final StreamController<PcmFrame> _pcmStreamCtrl;
  late final StreamController<SpectrumSettings> _spectrumCtrl;
  late final StreamController<WaveformData?> _waveformCtrl;

  late final Future<void> _tlsBundleReady;

  /// Path of the bundled CA pem extracted to a real filesystem location
  /// by [_autoConfigureTlsCaBundle]. Captured here so [setTlsCaFile]
  /// can restore the default with an empty argument.
  String? _autoTlsCaBundlePath;

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
        value,
        paramName,
        'Expected a finite double (got NaN/Infinity)',
      );
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

  /// Whether an `eof-reached` rising edge marks the genuine end of all
  /// playable content — the last (or only) playlist entry, with no active
  /// loop that will restart it. Used by the `eof-reached` hook to settle the
  /// transport without firing at a gapless mid-playlist boundary or on every
  /// loop wrap (either of which would flicker the play/pause button).
  bool _isEndOfContent() {
    if (_state.loop != Loop.off) return false;
    final items = _state.playlist.items;
    return items.isEmpty || _state.playlist.index >= items.length - 1;
  }

  /// Internal log helper — emits on the library-side log channel
  /// ([PlayerStream.internalLog]), kept separate from mpv's engine log
  /// stream ([PlayerStream.log]).
  void _internalLog(String message, {LogLevel level = LogLevel.info}) =>
      _internalLogCtrl.add(
        MpvLogEntry(prefix: 'mpv_audio_kit', level: level, text: message),
      );

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

    // Tear down the media-session controller before closing the
    // backing reactives — its subscriptions need live streams to
    // cancel cleanly, and its final `disable()` call to native
    // needs the controller still wired. `Player.dispose()` already
    // calls `setMediaSession(null)` (which tears the controller
    // down) before reaching here, but we double-check for safety in
    // case a future code path skips that step.
    final controller = _mediaSessionController;
    _mediaSessionController = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {
        // Best effort — never block disposal on session teardown.
      }
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
      _demuxerCacheState.close(),
      _mediaSession.close(),
    ]);
    await Future.wait<void>([
      _endFileCtrl.close(),
      _errorCtrl.close(),
      _logCtrl.close(),
      _internalLogCtrl.close(),
      _hookCtrl.close(),
      _seekCompletedCtrl.close(),
      _coverArtCtrl.close(),
      _mediaSessionCommandsCtrl.close(),
    ]);
  }
}
