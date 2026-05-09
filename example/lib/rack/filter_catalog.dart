// GENERATED — do not edit. Source:
//   libmpv-scripts/lavfi_codegen/generate_filter_catalog.py
// Re-run after AUDIO_FILTERS or schema.json changes.

// ignore_for_file: lines_longer_than_80_chars

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Categories shown in the picker sidebar — order is preserved.
enum FxCategory {
  dynamics,
  loudness,
  eq,
  filters,
  time,
  stereo,
  modulation,
  denoise,
  utilities,
}

extension FxCategoryX on FxCategory {
  String get title => switch (this) {
    FxCategory.dynamics => 'DYNAMICS',
    FxCategory.loudness => 'LOUDNESS',
    FxCategory.eq => 'EQUALIZATION',
    FxCategory.filters => 'FILTERS',
    FxCategory.time => 'TIME AND PITCH',
    FxCategory.stereo => 'STEREO',
    FxCategory.modulation => 'MODULATION',
    FxCategory.denoise => 'DENOISE',
    FxCategory.utilities => 'UTILITIES',
  };
}

/// Per-filter metadata: name, category, description, plus
/// closures the picker uses to read/write the filter's enabled
/// flag without dispatching on a string at runtime.
class FxMeta {
  final String name;
  final FxCategory category;
  final String description;
  final bool Function(AudioEffects bundle) isOn;
  final AudioEffects Function(AudioEffects bundle, bool on) toggle;

  const FxMeta({
    required this.name,
    required this.category,
    required this.description,
    required this.isOn,
    required this.toggle,
  });
}

/// Every filter compiled into the bundled libmpv build.
/// Order: by category, then by name within each category.
final List<FxMeta> filterCatalog = <FxMeta>[
  FxMeta(
    name: 'acompressor',
    category: FxCategory.dynamics,
    description:
        'A compressor is mainly used to reduce the dynamic range of a signal. Especially modern music is mostly compressed at a high ratio to improve the overall loudness. It\'s done to get the highest attention of a listener, "fatten" the sound and bring more "power" to the track. If a signal is compressed too much it may sound dull or "dead" afterwards or it may start to "pump" (which could be a powerful effect but can also destroy a track completely). The right compression is the key to reach a professional sound and is the high art of mixing and mastering. Because of its complex settings it may take a long time to get the right feeling for this kind of effect. Compression is done by detecting the volume above a chosen level `threshold` and dividing it by the factor set with `ratio`. So if you set the threshold to -12dB and your signal reaches -6dB a ratio of 2:1 will result in a signal at -9dB. Because an exact manipulation of the signal would cause distortion of the waveform the reduction can be levelled over the time. This is done by setting "Attack" and "Release". `attack` determines how long the signal has to rise above the threshold before any reduction will occur and `release` sets the time the signal has to fall below the threshold to reduce the reduction again. Shorter signals than the chosen attack time will be left untouched. The overall reduction of the signal can be made up afterwards with the `makeup` setting. So compressing the peaks of a signal about 6dB and raising the makeup to this level results in a signal twice as loud than the source. To gain a softer entry in the compression the `knee` flattens the hard edge at the threshold in the range of the chosen decibels. The filter accepts the following options:',
    isOn: (b) => b.acompressor.enabled,
    toggle: (b, on) =>
        b.copyWith(acompressor: b.acompressor.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'acontrast',
    category: FxCategory.dynamics,
    description:
        'Simple audio dynamic range compression/expansion filter. The filter accepts the following options:',
    isOn: (b) => b.acontrast.enabled,
    toggle: (b, on) => b.copyWith(acontrast: b.acontrast.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adrc',
    category: FxCategory.dynamics,
    description:
        'Apply spectral dynamic range controller filter to input audio stream. A description of the accepted options follows.',
    isOn: (b) => b.adrc.enabled,
    toggle: (b, on) => b.copyWith(adrc: b.adrc.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adynamicequalizer',
    category: FxCategory.dynamics,
    description:
        'Apply dynamic equalization to input audio stream. A description of the accepted options follows.',
    isOn: (b) => b.adynamicequalizer.enabled,
    toggle: (b, on) => b.copyWith(
      adynamicequalizer: b.adynamicequalizer.copyWith(enabled: on),
    ),
  ),
  FxMeta(
    name: 'adynamicsmooth',
    category: FxCategory.dynamics,
    description:
        'Apply dynamic smoothing to input audio stream. A description of the accepted options follows.',
    isOn: (b) => b.adynamicsmooth.enabled,
    toggle: (b, on) =>
        b.copyWith(adynamicsmooth: b.adynamicsmooth.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'agate',
    category: FxCategory.dynamics,
    description:
        'A gate is mainly used to reduce lower parts of a signal. This kind of signal processing reduces disturbing noise between useful signals. Gating is done by detecting the volume below a chosen level `threshold` and dividing it by the factor set with `ratio`. The bottom of the noise floor is set via `range`. Because an exact manipulation of the signal would cause distortion of the waveform the reduction can be levelled over time. This is done by setting `attack` and `release`. `attack` determines how long the signal has to fall below the threshold before any reduction will occur and `release` sets the time the signal has to rise above the threshold to reduce the reduction again. Shorter signals than the chosen attack time will be left untouched.',
    isOn: (b) => b.agate.enabled,
    toggle: (b, on) => b.copyWith(agate: b.agate.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'alimiter',
    category: FxCategory.dynamics,
    description:
        'The limiter prevents an input signal from rising over a desired threshold. This limiter uses lookahead technology to prevent your signal from distorting. It means that there is a small delay after the signal is processed. Keep in mind that the delay it produces is the attack time you set. The filter accepts the following options:',
    isOn: (b) => b.alimiter.enabled,
    toggle: (b, on) => b.copyWith(alimiter: b.alimiter.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'apsyclip',
    category: FxCategory.dynamics,
    description:
        'Apply Psychoacoustic clipper to input audio stream. The filter accepts the following options:',
    isOn: (b) => b.apsyclip.enabled,
    toggle: (b, on) => b.copyWith(apsyclip: b.apsyclip.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asoftclip',
    category: FxCategory.dynamics,
    description:
        'Apply audio soft clipping. Soft clipping is a type of distortion effect where the amplitude of a signal is saturated along a smooth curve, rather than the abrupt shape of hard-clipping. This filter accepts the following options:',
    isOn: (b) => b.asoftclip.enabled,
    toggle: (b, on) => b.copyWith(asoftclip: b.asoftclip.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'compand',
    category: FxCategory.dynamics,
    description:
        'Compress or expand the audio\'s dynamic range. It accepts the following parameters:',
    isOn: (b) => b.compand.enabled,
    toggle: (b, on) => b.copyWith(compand: b.compand.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'deesser',
    category: FxCategory.dynamics,
    description: 'Apply de-essing to the audio samples.',
    isOn: (b) => b.deesser.enabled,
    toggle: (b, on) => b.copyWith(deesser: b.deesser.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'mcompand',
    category: FxCategory.dynamics,
    description:
        'Multiband Compress or expand the audio\'s dynamic range. The input audio is divided into bands using 4th order Linkwitz-Riley IIRs. This is akin to the crossover of a loudspeaker, and results in flat frequency response when absent compander action. It accepts the following parameters:',
    isOn: (b) => b.mcompand.enabled,
    toggle: (b, on) => b.copyWith(mcompand: b.mcompand.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'drmeter',
    category: FxCategory.loudness,
    description:
        'Measure audio dynamic range. DR values of 14 and higher is found in very dynamic material. DR of 8 to 13 is found in transition material. And anything less that 8 have very poor dynamics and is very compressed. The filter accepts the following options:',
    isOn: (b) => b.drmeter.enabled,
    toggle: (b, on) => b.copyWith(drmeter: b.drmeter.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'dynaudnorm',
    category: FxCategory.loudness,
    description:
        'Dynamic Audio Normalizer. This filter applies a certain amount of gain to the input audio in order to bring its peak magnitude to a target level (e.g. 0 dBFS). However, in contrast to more "simple" normalization algorithms, the Dynamic Audio Normalizer *dynamically* re-adjusts the gain factor to the input audio. This allows for applying extra gain to the "quiet" sections of the audio while avoiding distortions or clipping the "loud" sections. In other words: The Dynamic Audio Normalizer will "even out" the volume of quiet and loud sections, in the sense that the volume of each section is brought to the same target level. Note, however, that the Dynamic Audio Normalizer achieves this goal *without* applying "dynamic range compressing". It will retain 100% of the dynamic range *within* each section of the audio file.',
    isOn: (b) => b.dynaudnorm.enabled,
    toggle: (b, on) =>
        b.copyWith(dynaudnorm: b.dynaudnorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'ebur128',
    category: FxCategory.loudness,
    description:
        'EBU R128 scanner filter. This filter takes an audio stream and analyzes its loudness level. By default, it logs a message at a frequency of 10Hz with the Momentary loudness (identified by `M`), Short-term loudness (`S`), Integrated loudness (`I`) and Loudness Range (`LRA`). The filter can only analyze streams which have sample format is double-precision floating point. The input stream will be converted to this specification, if needed. Users may need to insert aformat and/or aresample filters after this filter to obtain the original parameters. The filter also has a video output (see the `video` option) with a real time graph to observe the loudness evolution. The graphic contains the logged message mentioned above, so it is not printed anymore when this option is set, unless the verbose logging is set. The main graphing area contains the short-term loudness (3 seconds of analysis), and the gauge on the right is for the momentary loudness (400 milliseconds), but can optionally be configured to instead display short-term loudness (see `gauge`). The green area marks a +/- 1LU target range around the target loudness (-23LUFS by default, unless modified through `target`). More information about the Loudness Recommendation EBU R128 on http://tech.ebu.ch/loudness. The filter accepts the following options:',
    isOn: (b) => b.ebur128.enabled,
    toggle: (b, on) => b.copyWith(ebur128: b.ebur128.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'loudnorm',
    category: FxCategory.loudness,
    description:
        'EBU R128 loudness normalization. Includes both dynamic and linear normalization modes. Support for both single pass (livestreams, files) and double pass (files) modes. This algorithm can target IL, LRA, and maximum true peak. In dynamic mode, to accurately detect true peaks, the audio stream will be upsampled to 192 kHz. Use the `-ar` option or `aresample` filter to explicitly set an output sample rate. The filter accepts the following options:',
    isOn: (b) => b.loudnorm.enabled,
    toggle: (b, on) => b.copyWith(loudnorm: b.loudnorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'speechnorm',
    category: FxCategory.loudness,
    description:
        'Speech Normalizer. This filter expands or compresses each half-cycle of audio samples (local set of samples all above or all below zero and between two nearest zero crossings) depending on threshold value, so audio reaches target peak value under conditions controlled by below options. The filter accepts the following options:',
    isOn: (b) => b.speechnorm.enabled,
    toggle: (b, on) =>
        b.copyWith(speechnorm: b.speechnorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'anequalizer',
    category: FxCategory.eq,
    description:
        'High-order parametric multiband equalizer for each channel. It accepts the following parameters:',
    isOn: (b) => b.anequalizer.enabled,
    toggle: (b, on) =>
        b.copyWith(anequalizer: b.anequalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asubboost',
    category: FxCategory.eq,
    description:
        'Boost subwoofer frequencies. The filter accepts the following options:',
    isOn: (b) => b.asubboost.enabled,
    toggle: (b, on) => b.copyWith(asubboost: b.asubboost.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'atilt',
    category: FxCategory.eq,
    description:
        'Apply spectral tilt filter to audio stream. This filter apply any spectral roll-off slope over any specified frequency band. The filter accepts the following options:',
    isOn: (b) => b.atilt.enabled,
    toggle: (b, on) => b.copyWith(atilt: b.atilt.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'bass',
    category: FxCategory.eq,
    description:
        'Boost or cut the bass (lower) frequencies of the audio using a two-pole shelving filter with a response similar to that of a standard hi-fi\'s tone-controls. This is also known as shelving equalisation (EQ). The filter accepts the following options:',
    isOn: (b) => b.bass.enabled,
    toggle: (b, on) => b.copyWith(bass: b.bass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'biquad',
    category: FxCategory.eq,
    description:
        'Apply a biquad IIR filter with the given coefficients. Where `b0`, `b1`, `b2` and `a0`, `a1`, `a2` are the numerator and denominator coefficients respectively. and `channels`, `c` specify which channels to filter, by default all available are filtered. This filter supports the following commands:',
    isOn: (b) => b.biquad.enabled,
    toggle: (b, on) => b.copyWith(biquad: b.biquad.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'equalizer',
    category: FxCategory.eq,
    description:
        'Apply a two-pole peaking equalisation (EQ) filter. With this filter, the signal-level at and around a selected frequency can be increased or decreased, whilst (unlike bandpass and bandreject filters) that at all other frequencies is unchanged. In order to produce complex equalisation curves, this filter can be given several times, each with a different central frequency. The filter accepts the following options:',
    isOn: (b) => b.equalizer.enabled,
    toggle: (b, on) => b.copyWith(equalizer: b.equalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'firequalizer',
    category: FxCategory.eq,
    description:
        'Apply FIR Equalization using arbitrary frequency response. The filter accepts the following option:',
    isOn: (b) => b.firequalizer.enabled,
    toggle: (b, on) =>
        b.copyWith(firequalizer: b.firequalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'highshelf',
    category: FxCategory.eq,
    description:
        'Boost or cut treble (upper) frequencies of the audio using a two-pole shelving filter with a response similar to that of a standard hi-fi\'s tone-controls. This is also known as shelving equalisation (EQ). The filter accepts the following options:',
    isOn: (b) => b.highshelf.enabled,
    toggle: (b, on) => b.copyWith(highshelf: b.highshelf.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'lowshelf',
    category: FxCategory.eq,
    description:
        'Boost or cut the bass (lower) frequencies of the audio using a two-pole shelving filter with a response similar to that of a standard hi-fi\'s tone-controls. This is also known as shelving equalisation (EQ). The filter accepts the following options:',
    isOn: (b) => b.lowshelf.enabled,
    toggle: (b, on) => b.copyWith(lowshelf: b.lowshelf.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'superequalizer',
    category: FxCategory.eq,
    description:
        'Apply 18 band equalizer. The filter accepts the following options:',
    isOn: (b) => b.superequalizer.enabled,
    toggle: (b, on) =>
        b.copyWith(superequalizer: b.superequalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'tiltshelf',
    category: FxCategory.eq,
    description:
        'Boost or cut the lower frequencies and cut or boost higher frequencies of the audio using a two-pole shelving filter with a response similar to that of a standard hi-fi\'s tone-controls. This is also known as shelving equalisation (EQ). The filter accepts the following options:',
    isOn: (b) => b.tiltshelf.enabled,
    toggle: (b, on) => b.copyWith(tiltshelf: b.tiltshelf.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'treble',
    category: FxCategory.eq,
    description:
        'Boost or cut treble (upper) frequencies of the audio using a two-pole shelving filter with a response similar to that of a standard hi-fi\'s tone-controls. This is also known as shelving equalisation (EQ). The filter accepts the following options:',
    isOn: (b) => b.treble.enabled,
    toggle: (b, on) => b.copyWith(treble: b.treble.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'allpass',
    category: FxCategory.filters,
    description:
        'Apply a two-pole all-pass filter with central frequency (in Hz) `frequency`, and filter-width `width`. An all-pass filter changes the audio\'s frequency to phase relationship without changing its frequency to amplitude relationship. The filter accepts the following options:',
    isOn: (b) => b.allpass.enabled,
    toggle: (b, on) => b.copyWith(allpass: b.allpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asubcut',
    category: FxCategory.filters,
    description:
        'Cut subwoofer frequencies. This filter allows to set custom, steeper roll off than highpass filter, and thus is able to more attenuate frequency content in stop-band. The filter accepts the following options:',
    isOn: (b) => b.asubcut.enabled,
    toggle: (b, on) => b.copyWith(asubcut: b.asubcut.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asupercut',
    category: FxCategory.filters,
    description:
        'Cut super frequencies. The filter accepts the following options:',
    isOn: (b) => b.asupercut.enabled,
    toggle: (b, on) => b.copyWith(asupercut: b.asupercut.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asuperpass',
    category: FxCategory.filters,
    description:
        'Apply high order Butterworth band-pass filter. The filter accepts the following options:',
    isOn: (b) => b.asuperpass.enabled,
    toggle: (b, on) =>
        b.copyWith(asuperpass: b.asuperpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asuperstop',
    category: FxCategory.filters,
    description:
        'Apply high order Butterworth band-stop filter. The filter accepts the following options:',
    isOn: (b) => b.asuperstop.enabled,
    toggle: (b, on) =>
        b.copyWith(asuperstop: b.asuperstop.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'bandpass',
    category: FxCategory.filters,
    description:
        'Apply a two-pole Butterworth band-pass filter with central frequency `frequency`, and (3dB-point) band-width width. The `csg` option selects a constant skirt gain (peak gain = Q) instead of the default: constant 0dB peak gain. The filter roll off at 6dB per octave (20dB per decade). The filter accepts the following options:',
    isOn: (b) => b.bandpass.enabled,
    toggle: (b, on) => b.copyWith(bandpass: b.bandpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'bandreject',
    category: FxCategory.filters,
    description:
        'Apply a two-pole Butterworth band-reject filter with central frequency `frequency`, and (3dB-point) band-width `width`. The filter roll off at 6dB per octave (20dB per decade). The filter accepts the following options:',
    isOn: (b) => b.bandreject.enabled,
    toggle: (b, on) =>
        b.copyWith(bandreject: b.bandreject.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'highpass',
    category: FxCategory.filters,
    description:
        'Apply a high-pass filter with 3dB point frequency. The filter can be either single-pole, or double-pole (the default). The filter roll off at 6dB per pole per octave (20dB per pole per decade). The filter accepts the following options:',
    isOn: (b) => b.highpass.enabled,
    toggle: (b, on) => b.copyWith(highpass: b.highpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'lowpass',
    category: FxCategory.filters,
    description:
        'Apply a low-pass filter with 3dB point frequency. The filter can be either single-pole or double-pole (the default). The filter roll off at 6dB per pole per octave (20dB per pole per decade). The filter accepts the following options:',
    isOn: (b) => b.lowpass.enabled,
    toggle: (b, on) => b.copyWith(lowpass: b.lowpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adelay',
    category: FxCategory.time,
    description:
        'Delay one or more audio channels. Samples in delayed channel are filled with silence. The filter accepts the following option:',
    isOn: (b) => b.adelay.enabled,
    toggle: (b, on) => b.copyWith(adelay: b.adelay.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afreqshift',
    category: FxCategory.time,
    description:
        'Apply frequency shift to input audio samples. The filter accepts the following options:',
    isOn: (b) => b.afreqshift.enabled,
    toggle: (b, on) =>
        b.copyWith(afreqshift: b.afreqshift.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aphaseshift',
    category: FxCategory.time,
    description:
        'Apply phase shift to input audio samples. The filter accepts the following options:',
    isOn: (b) => b.aphaseshift.enabled,
    toggle: (b, on) =>
        b.copyWith(aphaseshift: b.aphaseshift.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aresample',
    category: FxCategory.time,
    description:
        'Resample the input audio to the specified parameters, using the libswresample library. If none are specified then the filter will automatically convert between its input and output. This filter is also able to stretch/squeeze the audio data to make it match the timestamps or to inject silence / cut out audio to make it match the timestamps, do a combination of both or do neither. The filter accepts the syntax [`sample_rate`:]`resampler_options`, where `sample_rate` expresses a sample rate and `resampler_options` is a list of `key`=`value` pairs, separated by ":". See the Resampler Options for the complete list of supported options. Resample the input audio to 44100Hz: - Stretch/squeeze samples to the given timestamps, with a maximum of 1000 samples per second compensation:',
    isOn: (b) => b.aresample.enabled,
    toggle: (b, on) => b.copyWith(aresample: b.aresample.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'atempo',
    category: FxCategory.time,
    description:
        'Adjust audio tempo. The filter accepts exactly one parameter, the audio tempo. If not specified then the filter will assume nominal 1.0 tempo. Tempo must be in the [0.5, 100.0] range. Note that tempo greater than 2 will skip some samples rather than blend them in. If for any reason this is a concern it is always possible to daisy-chain several instances of atempo to achieve the desired product tempo. Slow down audio to 80% tempo: - To speed up audio to 300% tempo: - To speed up audio to 300% tempo by daisy-chaining two atempo instances: This filter supports the following commands:',
    isOn: (b) => b.atempo.enabled,
    toggle: (b, on) => b.copyWith(atempo: b.atempo.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'compensationdelay',
    category: FxCategory.time,
    description:
        'Compensation Delay Line is a metric based delay to compensate differing positions of microphones or speakers. For example, you have recorded guitar with two microphones placed in different locations. Because the front of sound wave has fixed speed in normal conditions, the phasing of microphones can vary and depends on their location and interposition. The best sound mix can be achieved when these microphones are in phase (synchronized). Note that a distance of ~30 cm between microphones makes one microphone capture the signal in antiphase to the other microphone. That makes the final mix sound moody. This filter helps to solve phasing problems by adding different delays to each microphone track and make them synchronized. The best result can be reached when you take one track as base and synchronize other tracks one by one with it. Remember that synchronization/delay tolerance depends on sample rate, too. Higher sample rates will give more tolerance. The filter accepts the following parameters:',
    isOn: (b) => b.compensationdelay.enabled,
    toggle: (b, on) => b.copyWith(
      compensationdelay: b.compensationdelay.copyWith(enabled: on),
    ),
  ),
  FxMeta(
    name: 'rubberband',
    category: FxCategory.time,
    description:
        'Apply time-stretching and pitch-shifting with librubberband. To enable compilation of this filter, you need to configure FFmpeg with `--enable-librubberband`. The filter accepts the following options:',
    isOn: (b) => b.rubberband.enabled,
    toggle: (b, on) =>
        b.copyWith(rubberband: b.rubberband.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adecorrelate',
    category: FxCategory.stereo,
    description:
        'Apply decorrelation to input audio stream. The filter accepts the following options:',
    isOn: (b) => b.adecorrelate.enabled,
    toggle: (b, on) =>
        b.copyWith(adecorrelate: b.adecorrelate.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'channelmap',
    category: FxCategory.stereo,
    description:
        'Remap input channels to new locations. It accepts the following parameters:',
    isOn: (b) => b.channelmap.enabled,
    toggle: (b, on) =>
        b.copyWith(channelmap: b.channelmap.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'crossfeed',
    category: FxCategory.stereo,
    description:
        'Apply headphone crossfeed filter. Crossfeed is the process of blending the left and right channels of stereo audio recording. It is mainly used to reduce extreme stereo separation of low frequencies. The intent is to produce more speaker like sound to the listener. The filter accepts the following options:',
    isOn: (b) => b.crossfeed.enabled,
    toggle: (b, on) => b.copyWith(crossfeed: b.crossfeed.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'dialoguenhance',
    category: FxCategory.stereo,
    description:
        'Enhance dialogue in stereo audio. This filter accepts stereo input and produce surround (3.0) channels output. The newly produced front center channel have enhanced speech dialogue originally available in both stereo channels. This filter outputs front left and front right channels same as available in stereo input. The filter accepts the following options:',
    isOn: (b) => b.dialoguenhance.enabled,
    toggle: (b, on) =>
        b.copyWith(dialoguenhance: b.dialoguenhance.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'earwax',
    category: FxCategory.stereo,
    description:
        'Make audio easier to listen to on headphones. This filter adds `cues\' to 44.1kHz stereo (i.e. audio CD format) audio so that when listened to on headphones the stereo image is moved from inside your head (standard for headphones) to outside and in front of the listener (standard for speakers). Ported from SoX.',
    isOn: (b) => b.earwax.enabled,
    toggle: (b, on) => b.copyWith(earwax: b.earwax.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'extrastereo',
    category: FxCategory.stereo,
    description:
        'Linearly increases the difference between left and right channels which adds some sort of "live" effect to playback. The filter accepts the following options:',
    isOn: (b) => b.extrastereo.enabled,
    toggle: (b, on) =>
        b.copyWith(extrastereo: b.extrastereo.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'haas',
    category: FxCategory.stereo,
    description:
        'Apply Haas effect to audio. Note that this makes most sense to apply on mono signals. With this filter applied to mono signals it give some directionality and stretches its stereo image. The filter accepts the following options:',
    isOn: (b) => b.haas.enabled,
    toggle: (b, on) => b.copyWith(haas: b.haas.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'headphone',
    category: FxCategory.stereo,
    description:
        'Apply head-related transfer functions (HRTFs) to create virtual loudspeakers around the user for binaural listening via headphones. The HRIRs are provided via additional streams, for each channel one stereo input stream is needed. The filter accepts the following options:',
    isOn: (b) => b.headphone.enabled,
    toggle: (b, on) => b.copyWith(headphone: b.headphone.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'pan',
    category: FxCategory.stereo,
    description:
        'Mix channels with specific gain levels. The filter accepts the output channel layout followed by a set of channels definitions. This filter is also designed to efficiently remap the channels of an audio stream. The filter accepts parameters of the form: "`l`|`outdef`|`outdef`|..."',
    isOn: (b) => b.pan.enabled,
    toggle: (b, on) => b.copyWith(pan: b.pan.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'stereotools',
    category: FxCategory.stereo,
    description:
        'This filter has some handy utilities to manage stereo signals, for converting M/S stereo recordings to L/R signal while having control over the parameters or spreading the stereo image of master track. The filter accepts the following options:',
    isOn: (b) => b.stereotools.enabled,
    toggle: (b, on) =>
        b.copyWith(stereotools: b.stereotools.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'stereowiden',
    category: FxCategory.stereo,
    description:
        'This filter enhance the stereo effect by suppressing signal common to both channels and by delaying the signal of left into right and vice versa, thereby widening the stereo effect. The filter accepts the following options:',
    isOn: (b) => b.stereowiden.enabled,
    toggle: (b, on) =>
        b.copyWith(stereowiden: b.stereowiden.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'surround',
    category: FxCategory.stereo,
    description:
        'Apply audio surround upmix filter. This filter allows to produce multichannel output from audio stream. The filter accepts the following options:',
    isOn: (b) => b.surround.enabled,
    toggle: (b, on) => b.copyWith(surround: b.surround.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'virtualbass',
    category: FxCategory.stereo,
    description:
        'Apply audio Virtual Bass filter. This filter accepts stereo input and produce stereo with LFE (2.1) channels output. The newly produced LFE channel have enhanced virtual bass originally obtained from both stereo channels. This filter outputs front left and front right channels unchanged as available in stereo input. The filter accepts the following options:',
    isOn: (b) => b.virtualbass.enabled,
    toggle: (b, on) =>
        b.copyWith(virtualbass: b.virtualbass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'acrusher',
    category: FxCategory.modulation,
    description:
        'Reduce audio bit resolution. This filter is bit crusher with enhanced functionality. A bit crusher is used to audibly reduce number of bits an audio signal is sampled with. This doesn\'t change the bit depth at all, it just produces the effect. Material reduced in bit depth sounds more harsh and "digital". This filter is able to even round to continuous values instead of discrete bit depths. Additionally it has a D/C offset which results in different crushing of the lower and the upper half of the signal. An Anti-Aliasing setting is able to produce "softer" crushing sounds. Another feature of this filter is the logarithmic mode. This setting switches from linear distances between bits to logarithmic ones. The result is a much more "natural" sounding crusher which doesn\'t gate low signals for example. The human ear has a logarithmic perception, so this kind of crushing is much more pleasant. Logarithmic crushing is also able to get anti-aliased. The filter accepts the following options:',
    isOn: (b) => b.acrusher.enabled,
    toggle: (b, on) => b.copyWith(acrusher: b.acrusher.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aecho',
    category: FxCategory.modulation,
    description:
        'Apply echoing to the input audio. Echoes are reflected sound and can occur naturally amongst mountains (and sometimes large buildings) when talking or shouting; digital echo effects emulate this behaviour and are often used to help fill out the sound of a single instrument or vocal. The time difference between the original signal and the reflection is the `delay`, and the loudness of the reflected signal is the `decay`. Multiple echoes can have different delays and decays. A description of the accepted parameters follows.',
    isOn: (b) => b.aecho.enabled,
    toggle: (b, on) => b.copyWith(aecho: b.aecho.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aemphasis',
    category: FxCategory.modulation,
    description:
        'Audio emphasis filter creates or restores material directly taken from LPs or emphased CDs with different filter curves. E.g. to store music on vinyl the signal has to be altered by a filter first to even out the disadvantages of this recording medium. Once the material is played back the inverse filter has to be applied to restore the distortion of the frequency response. The filter accepts the following options:',
    isOn: (b) => b.aemphasis.enabled,
    toggle: (b, on) => b.copyWith(aemphasis: b.aemphasis.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aexciter',
    category: FxCategory.modulation,
    description:
        'An exciter is used to produce high sound that is not present in the original signal. This is done by creating harmonic distortions of the signal which are restricted in range and added to the original signal. An Exciter raises the upper end of an audio signal without simply raising the higher frequencies like an equalizer would do to create a more "crisp" or "brilliant" sound. The filter accepts the following options:',
    isOn: (b) => b.aexciter.enabled,
    toggle: (b, on) => b.copyWith(aexciter: b.aexciter.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aphaser',
    category: FxCategory.modulation,
    description:
        'Add a phasing effect to the input audio. A phaser filter creates series of peaks and troughs in the frequency spectrum. The position of the peaks and troughs are modulated so that they vary over time, creating a sweeping effect. A description of the accepted parameters follows.',
    isOn: (b) => b.aphaser.enabled,
    toggle: (b, on) => b.copyWith(aphaser: b.aphaser.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'apulsator',
    category: FxCategory.modulation,
    description:
        'Audio pulsator is something between an autopanner and a tremolo. But it can produce funny stereo effects as well. Pulsator changes the volume of the left and right channel based on a LFO (low frequency oscillator) with different waveforms and shifted phases. This filter have the ability to define an offset between left and right channel. An offset of 0 means that both LFO shapes match each other. The left and right channel are altered equally - a conventional tremolo. An offset of 50% means that the shape of the right channel is exactly shifted in phase (or moved backwards about half of the frequency) - pulsator acts as an autopanner. At 1 both curves match again. Every setting in between moves the phase shift gapless between all stages and produces some "bypassing" sounds with sine and triangle waveforms. The more you set the offset near 1 (starting from the 0.5) the faster the signal passes from the left to the right speaker. The filter accepts the following options:',
    isOn: (b) => b.apulsator.enabled,
    toggle: (b, on) => b.copyWith(apulsator: b.apulsator.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'chorus',
    category: FxCategory.modulation,
    description:
        'Add a chorus effect to the audio. Can make a single vocal sound like a chorus, but can also be applied to instrumentation. Chorus resembles an echo effect with a short delay, but whereas with echo the delay is constant, with chorus, it is varied using using sinusoidal or triangular modulation. The modulation depth defines the range the modulated delay is played before or after the delay. Hence the delayed sound will sound slower or faster, that is the delayed sound tuned around the original one, like in a chorus where some vocals are slightly off key. It accepts the following parameters:',
    isOn: (b) => b.chorus.enabled,
    toggle: (b, on) => b.copyWith(chorus: b.chorus.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'crystalizer',
    category: FxCategory.modulation,
    description:
        'Simple algorithm for audio noise sharpening. This filter linearly increases differences between each audio sample. The filter accepts the following options:',
    isOn: (b) => b.crystalizer.enabled,
    toggle: (b, on) =>
        b.copyWith(crystalizer: b.crystalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'dcshift',
    category: FxCategory.modulation,
    description:
        'Apply a DC shift to the audio. This can be useful to remove a DC offset (caused perhaps by a hardware problem in the recording chain) from the audio. The effect of a DC offset is reduced headroom and hence volume. The astats filter can be used to determine if a signal has a DC offset.',
    isOn: (b) => b.dcshift.enabled,
    toggle: (b, on) => b.copyWith(dcshift: b.dcshift.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'flanger',
    category: FxCategory.modulation,
    description:
        'Apply a flanging effect to the audio. The filter accepts the following options:',
    isOn: (b) => b.flanger.enabled,
    toggle: (b, on) => b.copyWith(flanger: b.flanger.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'hdcd',
    category: FxCategory.modulation,
    description:
        'Decodes High Definition Compatible Digital (HDCD) data. A 16-bit PCM stream with embedded HDCD codes is expanded into a 20-bit PCM stream. The filter supports the Peak Extend and Low-level Gain Adjustment features of HDCD, and detects the Transient Filter flag. When using the filter with wav, note the default encoding for wav is 16-bit, so the resulting 20-bit stream will be truncated back to 16-bit. Use something like @command{-acodec pcm_s24le} after the filter to get 24-bit PCM output. ffmpeg -i HDCD16.wav -af hdcd -c:a pcm_s24le OUT24.wav The filter accepts the following options:',
    isOn: (b) => b.hdcd.enabled,
    toggle: (b, on) => b.copyWith(hdcd: b.hdcd.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'tremolo',
    category: FxCategory.modulation,
    description:
        'Sinusoidal amplitude modulation. The filter accepts the following options:',
    isOn: (b) => b.tremolo.enabled,
    toggle: (b, on) => b.copyWith(tremolo: b.tremolo.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'vibrato',
    category: FxCategory.modulation,
    description:
        'Sinusoidal phase modulation. The filter accepts the following options:',
    isOn: (b) => b.vibrato.enabled,
    toggle: (b, on) => b.copyWith(vibrato: b.vibrato.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adeclick',
    category: FxCategory.denoise,
    description:
        'Remove impulsive noise from input audio. Samples detected as impulsive noise are replaced by interpolated samples using autoregressive modelling.',
    isOn: (b) => b.adeclick.enabled,
    toggle: (b, on) => b.copyWith(adeclick: b.adeclick.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adeclip',
    category: FxCategory.denoise,
    description:
        'Remove clipped samples from input audio. Samples detected as clipped are replaced by interpolated samples using autoregressive modelling.',
    isOn: (b) => b.adeclip.enabled,
    toggle: (b, on) => b.copyWith(adeclip: b.adeclip.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afftdn',
    category: FxCategory.denoise,
    description:
        'Denoise audio samples with FFT. A description of the accepted parameters follows.',
    isOn: (b) => b.afftdn.enabled,
    toggle: (b, on) => b.copyWith(afftdn: b.afftdn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afwtdn',
    category: FxCategory.denoise,
    description:
        'Reduce broadband noise from input samples using Wavelets. A description of the accepted options follows.',
    isOn: (b) => b.afwtdn.enabled,
    toggle: (b, on) => b.copyWith(afwtdn: b.afwtdn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'anlmdn',
    category: FxCategory.denoise,
    description:
        'Reduce broadband noise in audio samples using Non-Local Means algorithm. Each sample is adjusted by looking for other samples with similar contexts. This context similarity is defined by comparing their surrounding patches of size @option{p}. Patches are searched in an area of @option{r} around the sample. The filter accepts the following options:',
    isOn: (b) => b.anlmdn.enabled,
    toggle: (b, on) => b.copyWith(anlmdn: b.anlmdn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'arnndn',
    category: FxCategory.denoise,
    description:
        'Reduce noise from speech using Recurrent Neural Networks. This filter accepts the following options:',
    isOn: (b) => b.arnndn.enabled,
    toggle: (b, on) => b.copyWith(arnndn: b.arnndn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adenorm',
    category: FxCategory.utilities,
    description:
        'Remedy denormals in audio by adding extremely low-level noise. This filter shall be placed before any filter that can produce denormals. A description of the accepted parameters follows.',
    isOn: (b) => b.adenorm.enabled,
    toggle: (b, on) => b.copyWith(adenorm: b.adenorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aderivative',
    category: FxCategory.utilities,
    description:
        'Compute derivative/integral of audio stream. Applying both filters one after another produces original audio.',
    isOn: (b) => b.aderivative.enabled,
    toggle: (b, on) =>
        b.copyWith(aderivative: b.aderivative.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aeval',
    category: FxCategory.utilities,
    description:
        'Modify an audio signal according to the specified expressions. This filter accepts one or more expressions (one for each channel), which are evaluated and used to modify a corresponding audio signal. It accepts the following parameters:',
    isOn: (b) => b.aeval.enabled,
    toggle: (b, on) => b.copyWith(aeval: b.aeval.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afade',
    category: FxCategory.utilities,
    description:
        'Apply fade-in/out effect to input audio. A description of the accepted parameters follows.',
    isOn: (b) => b.afade.enabled,
    toggle: (b, on) => b.copyWith(afade: b.afade.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afftfilt',
    category: FxCategory.utilities,
    description: 'Apply arbitrary expressions to samples in frequency domain.',
    isOn: (b) => b.afftfilt.enabled,
    toggle: (b, on) => b.copyWith(afftfilt: b.afftfilt.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aformat',
    category: FxCategory.utilities,
    description:
        'Set output format constraints for the input audio. The framework will negotiate the most appropriate format to minimize conversions. It accepts the following parameters:',
    isOn: (b) => b.aformat.enabled,
    toggle: (b, on) => b.copyWith(aformat: b.aformat.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aiir',
    category: FxCategory.utilities,
    description:
        'Apply an arbitrary Infinite Impulse Response filter. It accepts the following parameters:',
    isOn: (b) => b.aiir.enabled,
    toggle: (b, on) => b.copyWith(aiir: b.aiir.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'apad',
    category: FxCategory.utilities,
    description:
        'Pad the end of an audio stream with silence. This can be used together with @command{ffmpeg} @option{-shortest} to extend audio streams to the same length as the video stream. A description of the accepted options follows.',
    isOn: (b) => b.apad.enabled,
    toggle: (b, on) => b.copyWith(apad: b.apad.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'silenceremove',
    category: FxCategory.utilities,
    description:
        'Remove silence from the beginning, middle or end of the audio. The filter accepts the following options:',
    isOn: (b) => b.silenceremove.enabled,
    toggle: (b, on) =>
        b.copyWith(silenceremove: b.silenceremove.copyWith(enabled: on)),
  ),
];
