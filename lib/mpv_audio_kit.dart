// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// mpv_audio_kit — Flutter audio player powered by libmpv.
///
/// Supports macOS, Windows, Linux, iOS, and Android.
///
/// ## Quick start
/// ```dart
/// import 'package:mpv_audio_kit/mpv_audio_kit.dart';
///
/// final player = Player();
///
/// player.stream.position.listen((pos) => print(pos));
/// player.stream.playing.listen((p)   => print('playing: $p'));
///
/// await player.open(Media('https://example.com/audio.mp3'));
/// await player.play();
///
/// // ...
/// await player.dispose();
/// ```
library;

export 'src/player/player.dart' show Player;
export 'src/player/player_api.dart' show PlayerApi;
export 'src/models/cover_art.dart' show CoverArt;
export 'src/dsp/band_processor.dart' show BandProcessor;
export 'src/models/fft_frame.dart' show FftFrame;
export 'src/models/pcm_frame.dart' show PcmFrame;
export 'src/models/waveform_data.dart' show WaveformData, WaveformLevel;
export 'src/models/waveform_region.dart' show WaveformRegion;
export 'src/types/settings/waveform_settings.dart' show WaveformSettings;
export 'src/types/settings/spectrum_settings.dart' show SpectrumSettings;
export 'src/types/enums/window_function.dart' show WindowFunction;
export 'src/types/enums/audio_effects.dart';
export 'src/types/settings/audio_effects_settings.dart';
export 'src/types/settings/extensions/adelay_channels.dart'
    show AdelayChannelsX;
export 'src/types/settings/extensions/aecho_taps.dart'
    show AechoTap, AechoTapsX;
export 'src/types/settings/extensions/afftdn_band_noise.dart'
    show
        AfftdnBandNoiseX,
        kAfftdnBandCount,
        kAfftdnBandNoiseDefault;
export 'src/types/settings/extensions/aiir_channels.dart'
    show AiirChannel, AiirChannelsX;
export 'src/types/settings/extensions/anequalizer_bands.dart'
    show AnequalizerBand, AnequalizerBandType, AnequalizerBandsX;
export 'src/types/settings/extensions/chorus_voices.dart'
    show ChorusVoice, ChorusVoicesX;
export 'src/types/settings/extensions/compand_envelopes.dart'
    show CompandEnvelope, CompandEnvelopesX;
export 'src/types/settings/extensions/compand_points.dart'
    show CompandPoint, CompandPointsX;
export 'src/types/settings/extensions/compand_soft_knee.dart'
    show CompandSoftKneeX, kCompandSoftKneeDefault;
export 'src/types/settings/extensions/firequalizer_entries.dart'
    show FirequalizerEntry, FirequalizerEntriesX;
export 'src/types/settings/extensions/mcompand_bands.dart'
    show McompandBand, McompandBandsX;
export 'src/types/settings/extensions/superequalizer_bands.dart'
    show
        SuperequalizerBandsX,
        kSuperequalizerBandCount,
        kSuperequalizerFrequencies,
        kSuperequalizerUnityGain;
export 'src/types/settings/cache_settings.dart' show CacheSettings;
export 'src/types/enums/cache.dart' show Cache;
export 'src/models/chapter.dart' show Chapter;
export 'src/models/media.dart' show Media;
export 'src/models/mpv_track.dart' show MpvTrack;
export 'src/types/settings/replay_gain_settings.dart' show ReplayGainSettings;
export 'src/types/enums/replay_gain.dart' show ReplayGain;
export 'src/models/playlist.dart' show Playlist;
export 'src/types/enums/loop.dart' show Loop;
export 'src/types/sealed/channels.dart' show Channels;
export 'src/models/device.dart' show Device;
export 'src/types/enums/format.dart' show Format;
export 'src/models/audio_params.dart' show AudioParams;
export 'src/types/enums/spdif.dart' show Spdif;
export 'src/types/sealed/track.dart' show Track;
export 'src/types/state/audio_output_state.dart' show AudioOutputState;
export 'src/types/enums/cover.dart' show Cover;
export 'src/types/enums/gapless.dart' show Gapless;
export 'src/types/enums/tap_side.dart' show TapSide;
export 'src/types/state/mpv_playback_state.dart' show MpvPlaybackState;
export 'src/events/mpv_log_entry.dart' show MpvLogEntry;
export 'src/events/mpv_hook_event.dart' show MpvHookEvent;
export 'src/types/enums/hook.dart' show Hook;
export 'src/types/enums/log_level.dart' show LogLevel;
export 'src/types/state/mpv_prefetch_state.dart' show MpvPrefetchState;
export 'src/events/mpv_player_error.dart'
    show
        MpvPlayerError,
        MpvEndFileError,
        MpvEndFileErrorX,
        MpvLogError,
        MpvEndFileReason,
        MpvFileEndedEvent,
        MpvFileEndedEventX;
export 'src/player/player_configuration.dart' show PlayerConfiguration;
export 'src/player/player_state.dart' show PlayerState;
export 'src/player/player_stream.dart' show PlayerStream;
export 'src/mpv_bindings.dart' show MpvLibraryException, MpvError;
export 'src/events/mpv_exception.dart' show MpvException;
export 'src/internals/library_loader.dart' show MpvAudioKit;
