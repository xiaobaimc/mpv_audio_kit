// GENERATED — do not edit. Source:
//   libmpv-scripts/lavfi_codegen/generate_filter_catalog.py
// Re-run after AUDIO_FILTERS or schema.json changes.

// ignore_for_file: lines_longer_than_80_chars

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Categories shown in the picker sidebar — order is preserved.
enum FxCategory {
  dynamics,
  eq,
  cutPass,
  pitchTime,
  stereo,
  modulation,
  denoise,
  utility,
}

extension FxCategoryX on FxCategory {
  String get title => switch (this) {
    FxCategory.dynamics => 'Dynamics & loudness',
    FxCategory.eq => 'Equalization & tone',
    FxCategory.cutPass => 'Filters (cut / pass)',
    FxCategory.pitchTime => 'Pitch, tempo & time',
    FxCategory.stereo => 'Stereo, channels & spatial',
    FxCategory.modulation => 'Modulation & creative',
    FxCategory.denoise => 'Denoise & restoration',
    FxCategory.utility => 'Analysis, fade & utilities',
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
        'A compressor is mainly used to reduce the dynamic range of a signal. Especial…',
    isOn: (b) => b.acompressor.enabled,
    toggle: (b, on) =>
        b.copyWith(acompressor: b.acompressor.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'acontrast',
    category: FxCategory.dynamics,
    description:
        'Simple audio dynamic range compression/expansion filter. The filter accepts t…',
    isOn: (b) => b.acontrast.enabled,
    toggle: (b, on) => b.copyWith(acontrast: b.acontrast.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adrc',
    category: FxCategory.dynamics,
    description:
        'Apply spectral dynamic range controller filter to input audio stream. A descr…',
    isOn: (b) => b.adrc.enabled,
    toggle: (b, on) => b.copyWith(adrc: b.adrc.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adynamicequalizer',
    category: FxCategory.dynamics,
    description:
        'Apply dynamic equalization to input audio stream. A description of the accept…',
    isOn: (b) => b.adynamicequalizer.enabled,
    toggle: (b, on) => b.copyWith(
      adynamicequalizer: b.adynamicequalizer.copyWith(enabled: on),
    ),
  ),
  FxMeta(
    name: 'adynamicsmooth',
    category: FxCategory.dynamics,
    description:
        'Apply dynamic smoothing to input audio stream. A description of the accepted…',
    isOn: (b) => b.adynamicsmooth.enabled,
    toggle: (b, on) =>
        b.copyWith(adynamicsmooth: b.adynamicsmooth.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'agate',
    category: FxCategory.dynamics,
    description:
        'A gate is mainly used to reduce lower parts of a signal. This kind of signal…',
    isOn: (b) => b.agate.enabled,
    toggle: (b, on) => b.copyWith(agate: b.agate.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'alimiter',
    category: FxCategory.dynamics,
    description:
        'The limiter prevents an input signal from rising over a desired threshold. Th…',
    isOn: (b) => b.alimiter.enabled,
    toggle: (b, on) => b.copyWith(alimiter: b.alimiter.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'apsyclip',
    category: FxCategory.dynamics,
    description:
        'Apply Psychoacoustic clipper to input audio stream. The filter accepts the fo…',
    isOn: (b) => b.apsyclip.enabled,
    toggle: (b, on) => b.copyWith(apsyclip: b.apsyclip.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asoftclip',
    category: FxCategory.dynamics,
    description:
        'Apply audio soft clipping. Soft clipping is a type of distortion effect where…',
    isOn: (b) => b.asoftclip.enabled,
    toggle: (b, on) => b.copyWith(asoftclip: b.asoftclip.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'compand',
    category: FxCategory.dynamics,
    description:
        'Compress or expand the audio\'s dynamic range. It accepts the following parame…',
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
    name: 'drmeter',
    category: FxCategory.dynamics,
    description:
        'Measure audio dynamic range. DR values of 14 and higher is found in very dyna…',
    isOn: (b) => b.drmeter.enabled,
    toggle: (b, on) => b.copyWith(drmeter: b.drmeter.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'dynaudnorm',
    category: FxCategory.dynamics,
    description:
        'Dynamic Audio Normalizer. This filter applies a certain amount of gain to the…',
    isOn: (b) => b.dynaudnorm.enabled,
    toggle: (b, on) =>
        b.copyWith(dynaudnorm: b.dynaudnorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'ebur128',
    category: FxCategory.dynamics,
    description:
        'EBU R128 scanner filter. This filter takes an audio stream and analyzes its l…',
    isOn: (b) => b.ebur128.enabled,
    toggle: (b, on) => b.copyWith(ebur128: b.ebur128.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'loudnorm',
    category: FxCategory.dynamics,
    description:
        'EBU R128 loudness normalization. Includes both dynamic and linear normalizati…',
    isOn: (b) => b.loudnorm.enabled,
    toggle: (b, on) => b.copyWith(loudnorm: b.loudnorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'mcompand',
    category: FxCategory.dynamics,
    description:
        'Multiband Compress or expand the audio\'s dynamic range. The input audio is di…',
    isOn: (b) => b.mcompand.enabled,
    toggle: (b, on) => b.copyWith(mcompand: b.mcompand.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'speechnorm',
    category: FxCategory.dynamics,
    description:
        'Speech Normalizer. This filter expands or compresses each half-cycle of audio…',
    isOn: (b) => b.speechnorm.enabled,
    toggle: (b, on) =>
        b.copyWith(speechnorm: b.speechnorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'anequalizer',
    category: FxCategory.eq,
    description:
        'High-order parametric multiband equalizer for each channel. It accepts the fo…',
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
        'Apply spectral tilt filter to audio stream. This filter apply any spectral ro…',
    isOn: (b) => b.atilt.enabled,
    toggle: (b, on) => b.copyWith(atilt: b.atilt.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'bass',
    category: FxCategory.eq,
    description:
        'Boost or cut the bass (lower) frequencies of the audio using a two-pole shelv…',
    isOn: (b) => b.bass.enabled,
    toggle: (b, on) => b.copyWith(bass: b.bass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'biquad',
    category: FxCategory.eq,
    description:
        'Apply a biquad IIR filter with the given coefficients. Where `b0`, `b1`, `b2`…',
    isOn: (b) => b.biquad.enabled,
    toggle: (b, on) => b.copyWith(biquad: b.biquad.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'equalizer',
    category: FxCategory.eq,
    description:
        'Apply a two-pole peaking equalisation (EQ) filter. With this filter, the sign…',
    isOn: (b) => b.equalizer.enabled,
    toggle: (b, on) => b.copyWith(equalizer: b.equalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'firequalizer',
    category: FxCategory.eq,
    description:
        'Apply FIR Equalization using arbitrary frequency response. The filter accepts…',
    isOn: (b) => b.firequalizer.enabled,
    toggle: (b, on) =>
        b.copyWith(firequalizer: b.firequalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'highshelf',
    category: FxCategory.eq,
    description:
        'Boost or cut treble (upper) frequencies of the audio using a two-pole shelvin…',
    isOn: (b) => b.highshelf.enabled,
    toggle: (b, on) => b.copyWith(highshelf: b.highshelf.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'lowshelf',
    category: FxCategory.eq,
    description:
        'Boost or cut the bass (lower) frequencies of the audio using a two-pole shelv…',
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
        'Boost or cut the lower frequencies and cut or boost higher frequencies of the…',
    isOn: (b) => b.tiltshelf.enabled,
    toggle: (b, on) => b.copyWith(tiltshelf: b.tiltshelf.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'treble',
    category: FxCategory.eq,
    description:
        'Boost or cut treble (upper) frequencies of the audio using a two-pole shelvin…',
    isOn: (b) => b.treble.enabled,
    toggle: (b, on) => b.copyWith(treble: b.treble.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'allpass',
    category: FxCategory.cutPass,
    description:
        'Apply a two-pole all-pass filter with central frequency (in Hz) `frequency`…',
    isOn: (b) => b.allpass.enabled,
    toggle: (b, on) => b.copyWith(allpass: b.allpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asubcut',
    category: FxCategory.cutPass,
    description:
        'Cut subwoofer frequencies. This filter allows to set custom, steeper roll off…',
    isOn: (b) => b.asubcut.enabled,
    toggle: (b, on) => b.copyWith(asubcut: b.asubcut.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asupercut',
    category: FxCategory.cutPass,
    description:
        'Cut super frequencies. The filter accepts the following options:',
    isOn: (b) => b.asupercut.enabled,
    toggle: (b, on) => b.copyWith(asupercut: b.asupercut.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asuperpass',
    category: FxCategory.cutPass,
    description:
        'Apply high order Butterworth band-pass filter. The filter accepts the followi…',
    isOn: (b) => b.asuperpass.enabled,
    toggle: (b, on) =>
        b.copyWith(asuperpass: b.asuperpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'asuperstop',
    category: FxCategory.cutPass,
    description:
        'Apply high order Butterworth band-stop filter. The filter accepts the followi…',
    isOn: (b) => b.asuperstop.enabled,
    toggle: (b, on) =>
        b.copyWith(asuperstop: b.asuperstop.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'bandpass',
    category: FxCategory.cutPass,
    description:
        'Apply a two-pole Butterworth band-pass filter with central frequency `frequen…',
    isOn: (b) => b.bandpass.enabled,
    toggle: (b, on) => b.copyWith(bandpass: b.bandpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'bandreject',
    category: FxCategory.cutPass,
    description:
        'Apply a two-pole Butterworth band-reject filter with central frequency `frequ…',
    isOn: (b) => b.bandreject.enabled,
    toggle: (b, on) =>
        b.copyWith(bandreject: b.bandreject.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'highpass',
    category: FxCategory.cutPass,
    description:
        'Apply a high-pass filter with 3dB point frequency. The filter can be either s…',
    isOn: (b) => b.highpass.enabled,
    toggle: (b, on) => b.copyWith(highpass: b.highpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'lowpass',
    category: FxCategory.cutPass,
    description:
        'Apply a low-pass filter with 3dB point frequency. The filter can be either si…',
    isOn: (b) => b.lowpass.enabled,
    toggle: (b, on) => b.copyWith(lowpass: b.lowpass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afreqshift',
    category: FxCategory.pitchTime,
    description:
        'Apply frequency shift to input audio samples. The filter accepts the followin…',
    isOn: (b) => b.afreqshift.enabled,
    toggle: (b, on) =>
        b.copyWith(afreqshift: b.afreqshift.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aphaseshift',
    category: FxCategory.pitchTime,
    description:
        'Apply phase shift to input audio samples. The filter accepts the following op…',
    isOn: (b) => b.aphaseshift.enabled,
    toggle: (b, on) =>
        b.copyWith(aphaseshift: b.aphaseshift.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aresample',
    category: FxCategory.pitchTime,
    description:
        'Resample the input audio to the specified parameters, using the libswresample…',
    isOn: (b) => b.aresample.enabled,
    toggle: (b, on) => b.copyWith(aresample: b.aresample.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'atempo',
    category: FxCategory.pitchTime,
    description:
        'Adjust audio tempo. The filter accepts exactly one parameter, the audio tempo…',
    isOn: (b) => b.atempo.enabled,
    toggle: (b, on) => b.copyWith(atempo: b.atempo.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'rubberband',
    category: FxCategory.pitchTime,
    description:
        'Apply time-stretching and pitch-shifting with librubberband. To enable compil…',
    isOn: (b) => b.rubberband.enabled,
    toggle: (b, on) =>
        b.copyWith(rubberband: b.rubberband.copyWith(enabled: on)),
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
        'Apply headphone crossfeed filter. Crossfeed is the process of blending the le…',
    isOn: (b) => b.crossfeed.enabled,
    toggle: (b, on) => b.copyWith(crossfeed: b.crossfeed.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'dialoguenhance',
    category: FxCategory.stereo,
    description:
        'Enhance dialogue in stereo audio. This filter accepts stereo input and produc…',
    isOn: (b) => b.dialoguenhance.enabled,
    toggle: (b, on) =>
        b.copyWith(dialoguenhance: b.dialoguenhance.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'earwax',
    category: FxCategory.stereo,
    description:
        'Make audio easier to listen to on headphones. This filter adds `cues\' to 44.1…',
    isOn: (b) => b.earwax.enabled,
    toggle: (b, on) => b.copyWith(earwax: b.earwax.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'extrastereo',
    category: FxCategory.stereo,
    description:
        'Linearly increases the difference between left and right channels which adds…',
    isOn: (b) => b.extrastereo.enabled,
    toggle: (b, on) =>
        b.copyWith(extrastereo: b.extrastereo.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'haas',
    category: FxCategory.stereo,
    description:
        'Apply Haas effect to audio. Note that this makes most sense to apply on mono…',
    isOn: (b) => b.haas.enabled,
    toggle: (b, on) => b.copyWith(haas: b.haas.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'headphone',
    category: FxCategory.stereo,
    description:
        'Apply head-related transfer functions (HRTFs) to create virtual loudspeakers…',
    isOn: (b) => b.headphone.enabled,
    toggle: (b, on) => b.copyWith(headphone: b.headphone.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'pan',
    category: FxCategory.stereo,
    description:
        'Mix channels with specific gain levels. The filter accepts the output channel…',
    isOn: (b) => b.pan.enabled,
    toggle: (b, on) => b.copyWith(pan: b.pan.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'stereotools',
    category: FxCategory.stereo,
    description:
        'This filter has some handy utilities to manage stereo signals, for converting…',
    isOn: (b) => b.stereotools.enabled,
    toggle: (b, on) =>
        b.copyWith(stereotools: b.stereotools.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'stereowiden',
    category: FxCategory.stereo,
    description:
        'This filter enhance the stereo effect by suppressing signal common to both ch…',
    isOn: (b) => b.stereowiden.enabled,
    toggle: (b, on) =>
        b.copyWith(stereowiden: b.stereowiden.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'surround',
    category: FxCategory.stereo,
    description:
        'Apply audio surround upmix filter. This filter allows to produce multichannel…',
    isOn: (b) => b.surround.enabled,
    toggle: (b, on) => b.copyWith(surround: b.surround.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'virtualbass',
    category: FxCategory.stereo,
    description:
        'Apply audio Virtual Bass filter. This filter accepts stereo input and produce…',
    isOn: (b) => b.virtualbass.enabled,
    toggle: (b, on) =>
        b.copyWith(virtualbass: b.virtualbass.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'acrusher',
    category: FxCategory.modulation,
    description:
        'Reduce audio bit resolution. This filter is bit crusher with enhanced functio…',
    isOn: (b) => b.acrusher.enabled,
    toggle: (b, on) => b.copyWith(acrusher: b.acrusher.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aecho',
    category: FxCategory.modulation,
    description:
        'Apply echoing to the input audio. Echoes are reflected sound and can occur na…',
    isOn: (b) => b.aecho.enabled,
    toggle: (b, on) => b.copyWith(aecho: b.aecho.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aemphasis',
    category: FxCategory.modulation,
    description:
        'Audio emphasis filter creates or restores material directly taken from LPs or…',
    isOn: (b) => b.aemphasis.enabled,
    toggle: (b, on) => b.copyWith(aemphasis: b.aemphasis.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aexciter',
    category: FxCategory.modulation,
    description:
        'An exciter is used to produce high sound that is not present in the original…',
    isOn: (b) => b.aexciter.enabled,
    toggle: (b, on) => b.copyWith(aexciter: b.aexciter.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aphaser',
    category: FxCategory.modulation,
    description:
        'Add a phasing effect to the input audio. A phaser filter creates series of pe…',
    isOn: (b) => b.aphaser.enabled,
    toggle: (b, on) => b.copyWith(aphaser: b.aphaser.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'apulsator',
    category: FxCategory.modulation,
    description:
        'Audio pulsator is something between an autopanner and a tremolo. But it can p…',
    isOn: (b) => b.apulsator.enabled,
    toggle: (b, on) => b.copyWith(apulsator: b.apulsator.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'chorus',
    category: FxCategory.modulation,
    description:
        'Add a chorus effect to the audio. Can make a single vocal sound like a chorus…',
    isOn: (b) => b.chorus.enabled,
    toggle: (b, on) => b.copyWith(chorus: b.chorus.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'crystalizer',
    category: FxCategory.modulation,
    description:
        'Simple algorithm for audio noise sharpening. This filter linearly increases d…',
    isOn: (b) => b.crystalizer.enabled,
    toggle: (b, on) =>
        b.copyWith(crystalizer: b.crystalizer.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'dcshift',
    category: FxCategory.modulation,
    description:
        'Apply a DC shift to the audio. This can be useful to remove a DC offset (caus…',
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
        'Decodes High Definition Compatible Digital (HDCD) data. A 16-bit PCM stream w…',
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
        'Remove impulsive noise from input audio. Samples detected as impulsive noise…',
    isOn: (b) => b.adeclick.enabled,
    toggle: (b, on) => b.copyWith(adeclick: b.adeclick.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adeclip',
    category: FxCategory.denoise,
    description:
        'Remove clipped samples from input audio. Samples detected as clipped are repl…',
    isOn: (b) => b.adeclip.enabled,
    toggle: (b, on) => b.copyWith(adeclip: b.adeclip.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adecorrelate',
    category: FxCategory.denoise,
    description:
        'Apply decorrelation to input audio stream. The filter accepts the following o…',
    isOn: (b) => b.adecorrelate.enabled,
    toggle: (b, on) =>
        b.copyWith(adecorrelate: b.adecorrelate.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adelay',
    category: FxCategory.denoise,
    description:
        'Delay one or more audio channels. Samples in delayed channel are filled with…',
    isOn: (b) => b.adelay.enabled,
    toggle: (b, on) => b.copyWith(adelay: b.adelay.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'adenorm',
    category: FxCategory.denoise,
    description:
        'Remedy denormals in audio by adding extremely low-level noise. This filter sh…',
    isOn: (b) => b.adenorm.enabled,
    toggle: (b, on) => b.copyWith(adenorm: b.adenorm.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aderivative',
    category: FxCategory.denoise,
    description:
        'Compute derivative/integral of audio stream. Applying both filters one after…',
    isOn: (b) => b.aderivative.enabled,
    toggle: (b, on) =>
        b.copyWith(aderivative: b.aderivative.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afftdn',
    category: FxCategory.denoise,
    description:
        'Denoise audio samples with FFT. A description of the accepted parameters foll…',
    isOn: (b) => b.afftdn.enabled,
    toggle: (b, on) => b.copyWith(afftdn: b.afftdn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afwtdn',
    category: FxCategory.denoise,
    description:
        'Reduce broadband noise from input samples using Wavelets. A description of th…',
    isOn: (b) => b.afwtdn.enabled,
    toggle: (b, on) => b.copyWith(afwtdn: b.afwtdn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'anlmdn',
    category: FxCategory.denoise,
    description:
        'Reduce broadband noise in audio samples using Non-Local Means algorithm. Each…',
    isOn: (b) => b.anlmdn.enabled,
    toggle: (b, on) => b.copyWith(anlmdn: b.anlmdn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'arnndn',
    category: FxCategory.denoise,
    description:
        'Reduce noise from speech using Recurrent Neural Networks. This filter accepts…',
    isOn: (b) => b.arnndn.enabled,
    toggle: (b, on) => b.copyWith(arnndn: b.arnndn.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'compensationdelay',
    category: FxCategory.denoise,
    description:
        'Compensation Delay Line is a metric based delay to compensate differing posit…',
    isOn: (b) => b.compensationdelay.enabled,
    toggle: (b, on) => b.copyWith(
      compensationdelay: b.compensationdelay.copyWith(enabled: on),
    ),
  ),
  FxMeta(
    name: 'aeval',
    category: FxCategory.utility,
    description:
        'Modify an audio signal according to the specified expressions. This filter ac…',
    isOn: (b) => b.aeval.enabled,
    toggle: (b, on) => b.copyWith(aeval: b.aeval.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afade',
    category: FxCategory.utility,
    description:
        'Apply fade-in/out effect to input audio. A description of the accepted parame…',
    isOn: (b) => b.afade.enabled,
    toggle: (b, on) => b.copyWith(afade: b.afade.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'afftfilt',
    category: FxCategory.utility,
    description: 'Apply arbitrary expressions to samples in frequency domain.',
    isOn: (b) => b.afftfilt.enabled,
    toggle: (b, on) => b.copyWith(afftfilt: b.afftfilt.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aformat',
    category: FxCategory.utility,
    description:
        'Set output format constraints for the input audio. The framework will negotia…',
    isOn: (b) => b.aformat.enabled,
    toggle: (b, on) => b.copyWith(aformat: b.aformat.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'aiir',
    category: FxCategory.utility,
    description:
        'Apply an arbitrary Infinite Impulse Response filter. It accepts the following…',
    isOn: (b) => b.aiir.enabled,
    toggle: (b, on) => b.copyWith(aiir: b.aiir.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'apad',
    category: FxCategory.utility,
    description:
        'Pad the end of an audio stream with silence. This can be used together with @…',
    isOn: (b) => b.apad.enabled,
    toggle: (b, on) => b.copyWith(apad: b.apad.copyWith(enabled: on)),
  ),
  FxMeta(
    name: 'silenceremove',
    category: FxCategory.utility,
    description:
        'Remove silence from the beginning, middle or end of the audio. The filter acc…',
    isOn: (b) => b.silenceremove.enabled,
    toggle: (b, on) =>
        b.copyWith(silenceremove: b.silenceremove.copyWith(enabled: on)),
  ),
];
