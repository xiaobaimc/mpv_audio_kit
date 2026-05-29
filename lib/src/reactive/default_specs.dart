// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../generated/audio_effects_settings.dart';
import '../internals/duration_seconds.dart';
import '../models/audio_params.dart';
import '../models/chapter.dart';
import '../models/device.dart';
import '../models/mpv_track.dart';
import '../player/player_state.dart';
import '../reactive/node_parsers.dart';
import '../types/enums/cache.dart';
import '../types/enums/cover.dart';
import '../types/enums/format.dart';
import '../types/enums/gapless.dart';
import '../types/enums/replay_gain.dart';
import '../types/enums/spdif.dart';
import '../types/sealed/channels.dart';
import '../types/settings/cache_settings.dart';
import '../types/settings/replay_gain_settings.dart';
import '../types/state/audio_output_state.dart';
import '../types/state/mpv_prefetch_state.dart';
import 'mpv_property_spec.dart';
import 'reactive_property.dart';

/// Bundles the [ReactiveProperty]s that back state fields the registry
/// "owns" — for the most part one per observed mpv property, but a few
/// (`playing`, `audioParams`, `cache`, `replayGain`) are aggregate cells
/// that several specs share so dedup happens on the full struct.
class DefaultPropertyReactives {
  /// Creates the bundle with every cell seeded to mpv's documented default.
  DefaultPropertyReactives();

  // Lifecycle.

  /// Actual-output axis: `true` only while mpv is genuinely producing
  /// audio. Mirrors `core-idle` inverted, so it toggles transiently on
  /// every seek and while buffering. Use it for spinners, not the
  /// play/pause button.
  final ReactiveProperty<bool> playing = ReactiveProperty<bool>(false);

  /// User intent to play (the play/pause axis). Distinct from [playing]
  /// (which mirrors `core-idle` — actual output). Driven by the
  /// play/pause/open/stop call sites plus an idle-active reset, never by
  /// mpv's `pause` property; unaffected by seeking or buffering.
  final ReactiveProperty<bool> playWhenReady = ReactiveProperty<bool>(false);

  // Playback / timing.

  /// Current playhead position (`time-pos`).
  final ReactiveProperty<Duration> position =
      ReactiveProperty<Duration>(Duration.zero);

  /// Total duration of the current file (`duration`).
  final ReactiveProperty<Duration> duration =
      ReactiveProperty<Duration>(Duration.zero);

  /// Buffered-ahead time as a wall-clock instant (`demuxer-cache-time`).
  final ReactiveProperty<Duration> buffer =
      ReactiveProperty<Duration>(Duration.zero);

  /// Output volume in percent (`volume`); `100` is unattenuated.
  final ReactiveProperty<double> volume = ReactiveProperty<double>(100.0);

  /// Playback rate multiplier (`speed`); `1.0` is normal speed.
  final ReactiveProperty<double> rate = ReactiveProperty<double>(1.0);

  /// Pitch multiplier (`pitch`); `1.0` leaves pitch unchanged.
  final ReactiveProperty<double> pitch = ReactiveProperty<double>(1.0);

  /// Whether output is muted (`mute`).
  final ReactiveProperty<bool> mute = ReactiveProperty<bool>(false);

  /// Whether the playlist is played in shuffled order (`shuffle`).
  final ReactiveProperty<bool> shuffle = ReactiveProperty<bool>(false);

  /// Whether pitch is held constant when [rate] changes
  /// (`audio-pitch-correction`).
  final ReactiveProperty<bool> pitchCorrection = ReactiveProperty<bool>(true);

  /// Audio-versus-video sync offset (`audio-delay`).
  final ReactiveProperty<Duration> audioDelay =
      ReactiveProperty<Duration>(Duration.zero);

  /// Measured audio bitrate (`audio-bitrate`); `null` until known.
  final ReactiveProperty<double?> audioBitrate =
      ReactiveProperty<double?>(null);

  /// Currently selected output device (`audio-device`).
  final ReactiveProperty<Device> audioDevice =
      ReactiveProperty<Device>(const Device(name: 'auto', description: 'Auto'));

  /// Decoder-side audio parameters — aggregate of `audio-params` (NODE),
  /// `audio-codec`, and `audio-codec-name`. The three specs all dedup and
  /// emit on this single cell so listeners see one [AudioParams] snapshot
  /// per change.
  final ReactiveProperty<AudioParams> audioParams =
      ReactiveProperty<AudioParams>(const AudioParams());

  /// Hardware-side audio parameters (`audio-out-params`) — a single
  /// node-map; mpv exposes no codec/codec-name siblings on the output side.
  final ReactiveProperty<AudioParams> audioOutParamsNode =
      ReactiveProperty<AudioParams>(const AudioParams());

  /// ReplayGain configuration — aggregate of `replaygain`,
  /// `replaygain-preamp`, `replaygain-fallback`, and `replaygain-clip`.
  /// All four specs dedup and emit on this single cell.
  final ReactiveProperty<ReplayGainSettings> replayGain =
      ReactiveProperty<ReplayGainSettings>(const ReplayGainSettings());

  /// Decoder-side gain applied on top of [volume] (`volume-gain`), in dB.
  final ReactiveProperty<double> volumeGain = ReactiveProperty<double>(0.0);

  /// Gapless-playback policy across playlist boundaries (`gapless-audio`).
  final ReactiveProperty<Gapless> gapless =
      ReactiveProperty<Gapless>(Gapless.weak);

  /// Demuxer cache configuration — aggregate of `cache`, `cache-secs`,
  /// `cache-on-disk`, `cache-pause`, and `cache-pause-wait`. All five
  /// specs dedup and emit on this single cell.
  final ReactiveProperty<CacheSettings> cache =
      ReactiveProperty<CacheSettings>(const CacheSettings());

  /// Forward demuxer cache size cap in bytes (`demuxer-max-bytes`).
  final ReactiveProperty<int> demuxerMaxBytes =
      ReactiveProperty<int>(150 * 1024 * 1024);

  /// Minimum read-ahead the demuxer keeps buffered (`demuxer-readahead-secs`).
  final ReactiveProperty<int> demuxerReadaheadSecs = ReactiveProperty<int>(1);

  /// Backward demuxer cache size cap in bytes (`demuxer-max-back-bytes`).
  final ReactiveProperty<int> demuxerMaxBackBytes =
      ReactiveProperty<int>(50 * 1024 * 1024);

  /// Network I/O timeout (`network-timeout`).
  final ReactiveProperty<Duration> networkTimeout =
      ReactiveProperty<Duration>(const Duration(seconds: 60));

  /// Whether the server certificate is verified for TLS streams
  /// (`tls-verify`).
  final ReactiveProperty<bool> tlsVerify = ReactiveProperty<bool>(false);

  /// Path to a custom CA bundle for TLS verification (`tls-ca-file`).
  final ReactiveProperty<String> tlsCaFile = ReactiveProperty<String>('');

  /// Whether playback is currently paused waiting for the cache to fill
  /// (`paused-for-cache`).
  final ReactiveProperty<bool> pausedForCache = ReactiveProperty<bool>(false);

  /// Whether the current source is being read over the network
  /// (`demuxer-via-network`).
  final ReactiveProperty<bool> demuxerViaNetwork =
      ReactiveProperty<bool>(false);

  /// Whether the audio device is opened in exclusive mode (`audio-exclusive`).
  final ReactiveProperty<bool> audioExclusive = ReactiveProperty<bool>(false);

  /// Output device buffer size (`audio-buffer`).
  final ReactiveProperty<Duration> audioBuffer =
      ReactiveProperty<Duration>(const Duration(milliseconds: 200));

  /// Whether silence is streamed to keep the device open while idle
  /// (`audio-stream-silence`).
  final ReactiveProperty<bool> audioStreamSilence =
      ReactiveProperty<bool>(false);

  /// Whether the null audio output runs untimed (`ao-null-untimed`).
  final ReactiveProperty<bool> audioNullUntimed = ReactiveProperty<bool>(false);

  /// Full track inventory of the current file (`track-list`).
  final ReactiveProperty<List<MpvTrack>> tracks =
      ReactiveProperty<List<MpvTrack>>(const []);

  /// Currently selected audio track (`current-tracks/audio`); `null` when
  /// none is active.
  final ReactiveProperty<MpvTrack?> currentAudioTrack =
      ReactiveProperty<MpvTrack?>(null);

  /// Set of codecs currently passed through as bitstream (`audio-spdif`).
  final ReactiveProperty<Set<Spdif>> audioSpdif =
      ReactiveProperty<Set<Spdif>>(const <Spdif>{});

  /// Upper bound the [volume] setter accepts (`volume-max`), in percent.
  final ReactiveProperty<double> volumeMax = ReactiveProperty<double>(130.0);

  /// Decoded audio sample rate in Hz (`audio-samplerate`).
  final ReactiveProperty<int> audioSampleRate = ReactiveProperty<int>(0);

  /// Forced output sample format (`audio-format`); [Format.auto] lets mpv
  /// pick.
  final ReactiveProperty<Format> audioFormat =
      ReactiveProperty<Format>(Format.auto);

  /// Forced output channel layout (`audio-channels`); [Channels.auto] lets
  /// mpv pick.
  final ReactiveProperty<Channels> audioChannels =
      ReactiveProperty<Channels>(Channels.auto);

  /// Client name reported to the audio server (`audio-client-name`).
  final ReactiveProperty<String> audioClientName =
      ReactiveProperty<String>('mpv_audio_kit');

  /// Active audio output driver (`ao`).
  final ReactiveProperty<String> audioDriver = ReactiveProperty<String>('auto');

  /// DSP pipeline — the single bundle reactive backing every effect. Each
  /// effect owns a reserved label inside the `af` pipeline and is upserted
  /// atomically when the bundle is replaced via `Player.setAudioEffects` /
  /// `updateAudioEffects`.
  final ReactiveProperty<AudioEffects> audioEffects =
      ReactiveProperty<AudioEffects>(const AudioEffects());

  /// Audio output lifecycle state (`audio-output-state`).
  final ReactiveProperty<AudioOutputState> audioOutputState =
      ReactiveProperty<AudioOutputState>(AudioOutputState.closed);

  /// Policy for scanning sidecar cover-art files (`cover-art-auto`).
  final ReactiveProperty<Cover> coverArtAuto =
      ReactiveProperty<Cover>(Cover.no);

  /// Background prefetch progress (`prefetch-state`). An event-shaped
  /// signal, not a snapshot value: the cell exists for dedup and dispose
  /// bookkeeping, but the value is exposed exclusively through
  /// [PlayerStream.prefetchState] — never read `.value` from outside.
  final ReactiveProperty<MpvPrefetchState> prefetchState =
      ReactiveProperty<MpvPrefetchState>(MpvPrefetchState.idle);

  /// Whether the next playlist entry is prefetched during playback
  /// (`prefetch-playlist`).
  final ReactiveProperty<bool> prefetchPlaylist = ReactiveProperty<bool>(false);

  /// Presentation timestamp of the audio currently being output
  /// (`audio-pts`).
  final ReactiveProperty<Duration> audioPts =
      ReactiveProperty<Duration>(Duration.zero);

  /// Time left until the end of the current file (`time-remaining`).
  final ReactiveProperty<Duration> timeRemaining =
      ReactiveProperty<Duration>(Duration.zero);

  /// Wall-clock time left at the current [rate] (`playtime-remaining`).
  final ReactiveProperty<Duration> playtimeRemaining =
      ReactiveProperty<Duration>(Duration.zero);

  /// Whether the decoder has reached end-of-file (`eof-reached`).
  final ReactiveProperty<bool> eofReached = ReactiveProperty<bool>(false);

  /// Whether the current stream supports seeking (`seekable`).
  final ReactiveProperty<bool> seekable = ReactiveProperty<bool>(false);

  /// Whether the current stream is seekable only within the cached range
  /// (`partially-seekable`).
  final ReactiveProperty<bool> partiallySeekable =
      ReactiveProperty<bool>(false);

  /// Human-readable title of the current media (`media-title`).
  final ReactiveProperty<String> mediaTitle = ReactiveProperty<String>('');

  /// Container format of the current file (`file-format`).
  final ReactiveProperty<String> fileFormat = ReactiveProperty<String>('');

  /// Size of the current file in bytes (`file-size`).
  final ReactiveProperty<int> fileSize = ReactiveProperty<int>(0);

  /// Buffered look-ahead beyond the playhead (`demuxer-cache-duration`).
  final ReactiveProperty<Duration> bufferDuration =
      ReactiveProperty<Duration>(Duration.zero);

  /// Whether the demuxer has stopped reading because its cache is full
  /// (`demuxer-cache-idle`).
  final ReactiveProperty<bool> demuxerIdle = ReactiveProperty<bool>(true);

  /// Index of the active chapter (`chapter`); `null` when none is active.
  final ReactiveProperty<int?> currentChapter = ReactiveProperty<int?>(null);

  /// Chapter list of the current file (`chapter-list`).
  final ReactiveProperty<List<Chapter>> chapters =
      ReactiveProperty<List<Chapter>>(const []);

  /// Resolved path or URI of the current file (`path`).
  final ReactiveProperty<String> path = ReactiveProperty<String>('');

  /// Filename component of the current file (`filename`).
  final ReactiveProperty<String> filename = ReactiveProperty<String>('');

  /// Path of the underlying stream after protocol resolution (`stream-path`).
  final ReactiveProperty<String> streamPath = ReactiveProperty<String>('');

  /// Filename mpv opened the stream with (`stream-open-filename`).
  final ReactiveProperty<String> streamOpenFilename =
      ReactiveProperty<String>('');

  /// A-loop point (`ab-loop-a`); `null` when the A-B loop start is unset.
  final ReactiveProperty<Duration?> abLoopA = ReactiveProperty<Duration?>(null);

  /// B-loop point (`ab-loop-b`); `null` when the A-B loop end is unset.
  final ReactiveProperty<Duration?> abLoopB = ReactiveProperty<Duration?>(null);

  /// Number of A-B loop repetitions requested (`ab-loop-count`); `null` is
  /// infinite.
  final ReactiveProperty<int?> abLoopCount = ReactiveProperty<int?>(null);

  /// Repetitions left in the active A-B loop (`remaining-ab-loops`); `null`
  /// is infinite.
  final ReactiveProperty<int?> remainingAbLoops = ReactiveProperty<int?>(null);

  /// Whether a seek is currently in flight (`seeking`).
  final ReactiveProperty<bool> seeking = ReactiveProperty<bool>(false);

  /// Playhead position as a percentage of duration (`percent-pos`).
  final ReactiveProperty<double> percentPos = ReactiveProperty<double>(0.0);

  /// Speed at which the cache is being filled (`cache-speed`), in bytes/s.
  final ReactiveProperty<double> cacheSpeed = ReactiveProperty<double>(0.0);

  /// Cache fill level as a percentage (`cache-buffering-state`).
  final ReactiveProperty<int> cacheBufferingState = ReactiveProperty<int>(0);

  /// Name of the demuxer handling the current file (`current-demuxer`).
  final ReactiveProperty<String> currentDemuxer = ReactiveProperty<String>('');

  /// Name of the active audio output (`current-ao`).
  final ReactiveProperty<String> currentAo = ReactiveProperty<String>('');

  /// Start timestamp of the current stream (`demuxer-start-time`).
  final ReactiveProperty<Duration> demuxerStartTime =
      ReactiveProperty<Duration>(Duration.zero);

  /// Metadata tags attached to the active chapter (`chapter-metadata`).
  final ReactiveProperty<Map<String, String>> chapterMetadata =
      ReactiveProperty<Map<String, String>>(const <String, String>{});

  /// mpv build version string (`mpv-version`).
  final ReactiveProperty<String> mpvVersion = ReactiveProperty<String>('');

  /// Linked ffmpeg version string (`ffmpeg-version`).
  final ReactiveProperty<String> ffmpegVersion = ReactiveProperty<String>('');
}

/// Builds the default list of [MpvPropertySpec]s mapping mpv property names
/// to their [PlayerState] reducers.
///
/// The callbacks let the caller hook side effects to property changes
/// without leaking the player object into the spec list:
/// - [onIdleActive]: fires every time mpv toggles `idle-active`; used by the
///   player to clear its lifecycle (`playing=false, buffering=false`) when
///   mpv has nothing left to do.
/// - [onAudioOutputState]: fires on every transition of
///   `audio-output-state`; the player uses it to surface a typed
///   error when the AO fails to initialise.
/// - [onEofReached]: fires on every transition of `eof-reached`; the player
///   uses the rising edge to settle the transport at the genuine end of
///   content (mark `completed`, release the play/pause intent) because the
///   shipped `keep-open: yes` makes mpv withhold both `END_FILE` and
///   `idle-active` when the last/only track finishes.
List<MpvPropertySpec<Object?>> buildDefaultSpecs(
  DefaultPropertyReactives r, {
  required void Function(bool idle) onIdleActive,
  required void Function(AudioOutputState state) onAudioOutputState,
  required void Function(bool eof) onEofReached,
}) {
  return <MpvPropertySpec<Object?>>[
    // ── Playback / timing ────────────────────────────────────────────────
    MpvPropertySpec<Duration>.double(
      name: 'time-pos',
      reactive: r.position,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(position: v),
    ),
    MpvPropertySpec<Duration>.double(
      name: 'duration',
      reactive: r.duration,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(duration: v),
    ),
    MpvPropertySpec<Duration>.double(
      name: 'demuxer-cache-time',
      reactive: r.buffer,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(buffer: v),
    ),
    // `state.playing = !core-idle`. mpv's `pause` defaults to `no`
    // while idle and doesn't fire PROPERTY_CHANGE on the load → playing
    // transition for the first file; `core-idle` flips reliably on
    // every start/stop/pause/seek/buffer/EOF.
    MpvPropertySpec<bool>.flag(
      name: 'core-idle',
      reactive: r.playing,
      parse: (raw, _) => !raw,
      reduce: (playing, s) => s.copyWith(playing: playing),
    ),
    // NOTE: `pause` is deliberately NOT observed. The intent axis
    // (`playWhenReady`) is driven purely by the play/pause/open/stop
    // call sites (plus an idle-active reset) — the same "intent changes
    // only on explicit method calls" model as ExoPlayer's
    // `playWhenReady` and just_audio's `playing`. Observing `pause`
    // would mis-report intent at idle (mpv's `pause` defaults to `no`
    // even when nothing is loaded) and the initial observe burst could
    // race the optimistic set on the first open.
    MpvPropertySpec<double>.double(
      name: 'volume',
      reactive: r.volume,
      parse: _identityDouble,
      reduce: (v, s) => s.copyWith(volume: v),
    ),
    MpvPropertySpec<double>.double(
      name: 'speed',
      reactive: r.rate,
      parse: _identityDouble,
      reduce: (v, s) => s.copyWith(rate: v),
    ),
    MpvPropertySpec<double>.double(
      name: 'pitch',
      reactive: r.pitch,
      parse: _identityDouble,
      reduce: (v, s) => s.copyWith(pitch: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'mute',
      reactive: r.mute,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(mute: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'idle-active',
      // No state field for idle-active; the side-effect (`onIdleActive`) does
      // the lifecycle work. We still need a reactive for dedup so repeated
      // `true → true` events don't refire the lifecycle helper.
      reactive: ReactiveProperty<bool>(false),
      parse: _identityBool,
      reduce: (_, s) => s,
      onChange: onIdleActive,
    ),
    MpvPropertySpec<bool>.flag(
      name: 'shuffle',
      reactive: r.shuffle,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(shuffle: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'audio-pitch-correction',
      reactive: r.pitchCorrection,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(pitchCorrection: v),
    ),
    MpvPropertySpec<Duration>.double(
      name: 'audio-delay',
      reactive: r.audioDelay,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(audioDelay: v),
    ),
    MpvPropertySpec<double?>.double(
      name: 'audio-bitrate',
      reactive: r.audioBitrate,
      parse: (raw, _) => raw > 0 ? raw : null,
      reduce: (v, s) => s.copyWith(audioBitrate: v),
    ),
    // `audio-device` lives outside the registry: the description must
    // cross-reference `state.audioDevices` (parsed from
    // `audio-device-list`), and specs don't have access to that
    // sibling state — the player's custom dispatcher does.

    // ── Audio params (decoder side) ──────────────────────────────────────
    // Aggregate cell shared by three specs. The `audio-params` node
    // carries five of the eight fields; codec and codecName arrive as
    // separate string properties below. Each spec folds its slice via
    // copyWith so the reactive dedups on the full struct.
    MpvPropertySpec<AudioParams>.node(
      name: 'audio-params',
      reactive: r.audioParams,
      parse: (raw, s) {
        final node = parseAudioParamsNode(raw);
        return s.audioParams.copyWith(
          format: node.format,
          sampleRate: node.sampleRate,
          channels: node.channels,
          channelCount: node.channelCount,
          hrChannels: node.hrChannels,
        );
      },
      reduce: (v, s) => s.copyWith(audioParams: v),
    ),
    // `codec` and `codecName` mirror mpv's two codec properties one-to-one;
    // their content varies across mpv builds (`mp3` vs `mp3float`, `aac`
    // vs `aac_lc`, and the short-vs-descriptive split is not stable
    // either). Treat both fields as opaque hints — see the field-level
    // dartdoc on [AudioParams] for the matching contract.
    MpvPropertySpec<AudioParams>.string(
      name: 'audio-codec',
      reactive: r.audioParams,
      parse: (raw, s) =>
          s.audioParams.copyWith(codec: raw.isEmpty ? null : raw),
      reduce: (v, s) => s.copyWith(audioParams: v),
    ),
    MpvPropertySpec<AudioParams>.string(
      name: 'audio-codec-name',
      reactive: r.audioParams,
      parse: (raw, s) =>
          s.audioParams.copyWith(codecName: raw.isEmpty ? null : raw),
      reduce: (v, s) => s.copyWith(audioParams: v),
    ),

    // ── Audio params (hardware side) ─────────────────────────────────────
    MpvPropertySpec<AudioParams>.node(
      name: 'audio-out-params',
      reactive: r.audioOutParamsNode,
      parse: (raw, _) => parseAudioParamsNode(raw),
      reduce: (v, s) => s.copyWith(audioOutParams: v),
    ),

    // ── ReplayGain & gapless ─────────────────────────────────────────────
    MpvPropertySpec<Gapless>.string(
      name: 'gapless-audio',
      reactive: r.gapless,
      parse: (raw, _) => Gapless.fromMpv(raw),
      reduce: (v, s) => s.copyWith(gapless: v),
    ),
    // ── ReplayGain ───────────────────────────────────────────────────────
    // Aggregate cell — same pattern as audio-params above: four specs
    // share one reactive that dedups on the full [ReplayGainSettings].
    MpvPropertySpec<ReplayGainSettings>.string(
      name: 'replaygain',
      reactive: r.replayGain,
      parse: (raw, s) => s.replayGain.copyWith(mode: ReplayGain.fromMpv(raw)),
      reduce: (v, s) => s.copyWith(replayGain: v),
    ),
    MpvPropertySpec<ReplayGainSettings>.double(
      name: 'replaygain-preamp',
      reactive: r.replayGain,
      parse: (raw, s) => s.replayGain.copyWith(preamp: raw),
      reduce: (v, s) => s.copyWith(replayGain: v),
    ),
    MpvPropertySpec<ReplayGainSettings>.double(
      name: 'replaygain-fallback',
      reactive: r.replayGain,
      parse: (raw, s) => s.replayGain.copyWith(fallback: raw),
      reduce: (v, s) => s.copyWith(replayGain: v),
    ),
    MpvPropertySpec<ReplayGainSettings>.flag(
      name: 'replaygain-clip',
      reactive: r.replayGain,
      parse: (raw, s) => s.replayGain.copyWith(clip: raw),
      reduce: (v, s) => s.copyWith(replayGain: v),
    ),
    MpvPropertySpec<double>.double(
      name: 'volume-gain',
      reactive: r.volumeGain,
      parse: _identityDouble,
      reduce: (v, s) => s.copyWith(volumeGain: v),
    ),

    // ── Cache ────────────────────────────────────────────────────────────
    // Aggregate cell — five specs share one reactive that dedups on the
    // full [CacheSettings].
    MpvPropertySpec<CacheSettings>.string(
      name: 'cache',
      reactive: r.cache,
      parse: (raw, s) => s.cache.copyWith(mode: Cache.fromMpv(raw)),
      reduce: (v, s) => s.copyWith(cache: v),
    ),
    MpvPropertySpec<CacheSettings>.double(
      name: 'cache-secs',
      reactive: r.cache,
      parse: (raw, s) => s.cache.copyWith(secs: secondsToDuration(raw)),
      reduce: (v, s) => s.copyWith(cache: v),
    ),
    MpvPropertySpec<CacheSettings>.flag(
      name: 'cache-on-disk',
      reactive: r.cache,
      parse: (raw, s) => s.cache.copyWith(onDisk: raw),
      reduce: (v, s) => s.copyWith(cache: v),
    ),
    MpvPropertySpec<CacheSettings>.flag(
      name: 'cache-pause',
      reactive: r.cache,
      parse: (raw, s) => s.cache.copyWith(pause: raw),
      reduce: (v, s) => s.copyWith(cache: v),
    ),
    MpvPropertySpec<CacheSettings>.double(
      name: 'cache-pause-wait',
      reactive: r.cache,
      parse: (raw, s) => s.cache.copyWith(pauseWait: secondsToDuration(raw)),
      reduce: (v, s) => s.copyWith(cache: v),
    ),
    MpvPropertySpec<int>.int64(
      name: 'demuxer-max-bytes',
      reactive: r.demuxerMaxBytes,
      parse: _identityInt,
      reduce: (v, s) => s.copyWith(demuxerMaxBytes: v),
    ),
    MpvPropertySpec<int>.int64(
      name: 'demuxer-readahead-secs',
      reactive: r.demuxerReadaheadSecs,
      parse: _identityInt,
      reduce: (v, s) => s.copyWith(demuxerReadaheadSecs: v),
    ),
    MpvPropertySpec<int>.int64(
      name: 'demuxer-max-back-bytes',
      reactive: r.demuxerMaxBackBytes,
      parse: _identityInt,
      reduce: (v, s) => s.copyWith(demuxerMaxBackBytes: v),
    ),
    MpvPropertySpec<Duration>.double(
      name: 'network-timeout',
      reactive: r.networkTimeout,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(networkTimeout: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'tls-verify',
      reactive: r.tlsVerify,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(tlsVerify: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'paused-for-cache',
      reactive: r.pausedForCache,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(pausedForCache: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'demuxer-via-network',
      reactive: r.demuxerViaNetwork,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(demuxerViaNetwork: v),
    ),

    // ── Audio output / driver ────────────────────────────────────────────
    MpvPropertySpec<Duration>.double(
      name: 'audio-buffer',
      reactive: r.audioBuffer,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(audioBuffer: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'audio-exclusive',
      reactive: r.audioExclusive,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(audioExclusive: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'audio-stream-silence',
      reactive: r.audioStreamSilence,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(audioStreamSilence: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'ao-null-untimed',
      reactive: r.audioNullUntimed,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(audioNullUntimed: v),
    ),
    // Track inventory + currently-active audio track. mpv exposes these
    // as structured node trees; the typed [MpvTrack] model lets a UI
    // build a "switch audio track" picker without touching `aid` strings.
    MpvPropertySpec<List<MpvTrack>>.node(
      name: 'track-list',
      reactive: r.tracks,
      parse: (raw, _) => parseTrackListNode(raw),
      reduce: (v, s) => s.copyWith(tracks: v),
    ),
    MpvPropertySpec<MpvTrack?>.node(
      name: 'current-tracks/audio',
      reactive: r.currentAudioTrack,
      parse: (raw, _) => parseCurrentTrackNode(raw),
      reduce: (v, s) => s.copyWith(currentAudioTrack: v),
    ),
    MpvPropertySpec<Set<Spdif>>.string(
      name: 'audio-spdif',
      reactive: r.audioSpdif,
      parse: (raw, _) => Spdif.parseMpvList(raw),
      reduce: (v, s) => s.copyWith(audioSpdif: v),
    ),
    MpvPropertySpec<double>.double(
      name: 'volume-max',
      reactive: r.volumeMax,
      parse: _identityDouble,
      reduce: (v, s) => s.copyWith(volumeMax: v),
    ),
    MpvPropertySpec<int>.int64(
      name: 'audio-samplerate',
      reactive: r.audioSampleRate,
      parse: _identityInt,
      reduce: (v, s) => s.copyWith(audioSampleRate: v),
    ),
    MpvPropertySpec<Format>.string(
      name: 'audio-format',
      reactive: r.audioFormat,
      parse: (raw, _) => Format.fromMpv(raw),
      reduce: (v, s) => s.copyWith(audioFormat: v),
    ),
    MpvPropertySpec<Channels>.string(
      name: 'audio-channels',
      reactive: r.audioChannels,
      parse: (raw, _) => Channels.fromMpv(raw),
      reduce: (v, s) => s.copyWith(audioChannels: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'audio-client-name',
      reactive: r.audioClientName,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(audioClientName: v),
    ),
    // mpv's `af` property is owned exclusively by `setAudioEffects` /
    // `updateAudioEffects` — the typed [AudioEffects] bundle (including
    // its `custom` raw passthrough slot) is the only writer. Raw writes
    // to `af` are rejected by `setRawProperty`, so the property is not
    // observed here.
    MpvPropertySpec<String>.string(
      name: 'ao',
      reactive: r.audioDriver,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(audioDriver: v),
    ),

    // ── Cover art (external file scan policy) ────────────────────────────
    MpvPropertySpec<Cover>.string(
      name: 'cover-art-auto',
      reactive: r.coverArtAuto,
      parse: (raw, _) => Cover.fromMpv(raw),
      reduce: (v, s) => s.copyWith(coverArtAuto: v),
    ),

    // `prefetch-state` is stream-only (no PlayerState field) —
    // exposed through `Player.stream.prefetchState`.
    MpvPropertySpec<MpvPrefetchState>.string(
      name: 'prefetch-state',
      reactive: r.prefetchState,
      parse: (raw, _) => MpvPrefetchState.fromMpv(raw),
      reduce: (_, s) => s,
    ),
    MpvPropertySpec<AudioOutputState>.string(
      name: 'audio-output-state',
      reactive: r.audioOutputState,
      parse: (raw, _) => AudioOutputState.fromMpv(raw),
      reduce: (v, s) => s.copyWith(audioOutputState: v),
      onChange: onAudioOutputState,
    ),
    MpvPropertySpec<bool>.flag(
      name: 'prefetch-playlist',
      reactive: r.prefetchPlaylist,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(prefetchPlaylist: v),
    ),

    // ── Playback timing extras ───────────────────────────────────────────
    MpvPropertySpec<Duration>.double(
      name: 'audio-pts',
      reactive: r.audioPts,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(audioPts: v),
    ),
    MpvPropertySpec<Duration>.double(
      name: 'time-remaining',
      reactive: r.timeRemaining,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(timeRemaining: v),
    ),
    MpvPropertySpec<Duration>.double(
      name: 'playtime-remaining',
      reactive: r.playtimeRemaining,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(playtimeRemaining: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'eof-reached',
      reactive: r.eofReached,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(eofReached: v),
      onChange: onEofReached,
    ),

    // ── Stream capability ────────────────────────────────────────────────
    MpvPropertySpec<bool>.flag(
      name: 'seekable',
      reactive: r.seekable,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(seekable: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'partially-seekable',
      reactive: r.partiallySeekable,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(partiallySeekable: v),
    ),

    // ── Display / file metadata ──────────────────────────────────────────
    MpvPropertySpec<String>.string(
      name: 'media-title',
      reactive: r.mediaTitle,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(mediaTitle: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'file-format',
      reactive: r.fileFormat,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(fileFormat: v),
    ),
    MpvPropertySpec<int>.int64(
      name: 'file-size',
      reactive: r.fileSize,
      parse: _identityInt,
      reduce: (v, s) => s.copyWith(fileSize: v),
    ),

    // ── Buffering depth ──────────────────────────────────────────────────
    MpvPropertySpec<Duration>.double(
      name: 'demuxer-cache-duration',
      reactive: r.bufferDuration,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(bufferDuration: v),
    ),
    MpvPropertySpec<bool>.flag(
      name: 'demuxer-cache-idle',
      reactive: r.demuxerIdle,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(demuxerIdle: v),
    ),

    // ── Chapter navigation ───────────────────────────────────────────────
    // mpv emits `chapter = -1` when no chapter is active; map to `null`.
    MpvPropertySpec<int?>.int64(
      name: 'chapter',
      reactive: r.currentChapter,
      parse: (raw, _) => raw < 0 ? null : raw,
      reduce: (v, s) => s.copyWith(currentChapter: v),
    ),
    MpvPropertySpec<List<Chapter>>.node(
      name: 'chapter-list',
      reactive: r.chapters,
      parse: (raw, _) => parseChapterListNode(raw),
      reduce: (v, s) => s.copyWith(chapters: v),
    ),

    // ── Path / URI introspection (read-only) ─────────────────────────────
    MpvPropertySpec<String>.string(
      name: 'path',
      reactive: r.path,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(path: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'filename',
      reactive: r.filename,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(filename: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'stream-path',
      reactive: r.streamPath,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(streamPath: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'stream-open-filename',
      reactive: r.streamOpenFilename,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(streamOpenFilename: v),
    ),

    // ── A-B loop ────────────────────────────────────────────────────────
    // mpv emits `ab-loop-a` / `-b` as STRING (`'no'` when disabled, a
    // numeric string otherwise — `OPT_TIME` with `M_OPT_ALLOW_NO`).
    MpvPropertySpec<Duration?>.string(
      name: 'ab-loop-a',
      reactive: r.abLoopA,
      parse: (raw, _) => _parseAbLoopTime(raw),
      reduce: (v, s) => s.copyWith(abLoopA: v),
    ),
    MpvPropertySpec<Duration?>.string(
      name: 'ab-loop-b',
      reactive: r.abLoopB,
      parse: (raw, _) => _parseAbLoopTime(raw),
      reduce: (v, s) => s.copyWith(abLoopB: v),
    ),
    // `ab-loop-count` is `OPT_CHOICE` with `'inf'=-1` and a non-negative
    // numeric range. We surface it as a nullable int (`null` = inf).
    MpvPropertySpec<int?>.string(
      name: 'ab-loop-count',
      reactive: r.abLoopCount,
      parse: (raw, _) => _parseAbLoopCount(raw),
      reduce: (v, s) => s.copyWith(abLoopCount: v),
    ),
    // Read-only int. `-1` from mpv == infinity; map to `null`.
    MpvPropertySpec<int?>.int64(
      name: 'remaining-ab-loops',
      reactive: r.remainingAbLoops,
      parse: (raw, _) => raw < 0 ? null : raw,
      reduce: (v, s) => s.copyWith(remainingAbLoops: v),
    ),

    // ── Tier 2 introspection ────────────────────────────────────────────
    MpvPropertySpec<bool>.flag(
      name: 'seeking',
      reactive: r.seeking,
      parse: _identityBool,
      reduce: (v, s) => s.copyWith(seeking: v),
    ),
    MpvPropertySpec<double>.double(
      name: 'percent-pos',
      reactive: r.percentPos,
      parse: _identityDouble,
      reduce: (v, s) => s.copyWith(percentPos: v),
    ),
    MpvPropertySpec<double>.double(
      name: 'cache-speed',
      reactive: r.cacheSpeed,
      parse: _identityDouble,
      reduce: (v, s) => s.copyWith(cacheSpeed: v),
    ),
    MpvPropertySpec<int>.int64(
      name: 'cache-buffering-state',
      reactive: r.cacheBufferingState,
      parse: _identityInt,
      reduce: (v, s) => s.copyWith(cacheBufferingState: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'current-demuxer',
      reactive: r.currentDemuxer,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(currentDemuxer: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'current-ao',
      reactive: r.currentAo,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(currentAo: v),
    ),
    MpvPropertySpec<Duration>.double(
      name: 'demuxer-start-time',
      reactive: r.demuxerStartTime,
      parse: _toDuration,
      reduce: (v, s) => s.copyWith(demuxerStartTime: v),
    ),
    MpvPropertySpec<Map<String, String>>.node(
      name: 'chapter-metadata',
      reactive: r.chapterMetadata,
      parse: (raw, _) => _parseStringMap(raw),
      reduce: (v, s) => s.copyWith(chapterMetadata: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'mpv-version',
      reactive: r.mpvVersion,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(mpvVersion: v),
    ),
    MpvPropertySpec<String>.string(
      name: 'ffmpeg-version',
      reactive: r.ffmpegVersion,
      parse: _identityString,
      reduce: (v, s) => s.copyWith(ffmpegVersion: v),
    ),
  ];
}

/// Decodes a `MPV_FORMAT_NODE_MAP` whose values are uniformly strings
/// (mpv emits this shape for `chapter-metadata`, `vf-metadata`, …).
/// Falls back to an empty map on a non-map payload — a single malformed
/// emission shouldn't tear down the metadata view.
Map<String, String> _parseStringMap(dynamic raw) {
  if (raw is! Map) return const <String, String>{};
  return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
}

// ── Tiny inline parsers used by buildDefaultSpecs ──────────────────────────

double _identityDouble(double raw, PlayerState _) => raw;
int _identityInt(int raw, PlayerState _) => raw;
bool _identityBool(bool raw, PlayerState _) => raw;
String _identityString(String raw, PlayerState _) => raw;
Duration _toDuration(double raw, PlayerState _) => secondsToDuration(raw);

/// `ab-loop-a` / `ab-loop-b` parser. mpv emits `'no'` when disabled
/// (the `M_OPT_ALLOW_NO` flag on `OPT_TIME`); any other value is a
/// numeric string in seconds.
Duration? _parseAbLoopTime(String raw) {
  if (raw == 'no' || raw.isEmpty) return null;
  final secs = double.tryParse(raw);
  if (secs == null || secs.isNaN) return null;
  return secondsToDuration(secs);
}

/// `ab-loop-count` parser. `'inf'` = infinite; non-negative int = explicit
/// repetition count.
int? _parseAbLoopCount(String raw) {
  if (raw == 'inf' || raw.isEmpty) return null;
  return int.tryParse(raw);
}
