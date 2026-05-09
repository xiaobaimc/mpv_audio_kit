import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'generic_filter_window.dart';

/// Per-filter row specs for the simple "knob-grid" filters. Each
/// builder reads the current bundle from [Player.state.audioEffects],
/// composes its row list, and writes back via
/// [Player.updateAudioEffects].
///
/// Coverage policy: every filter NOT in `proWindowFilters` should
/// have an entry here. Each entry exposes the filter's most
/// commonly-tweaked numeric / enum parameters; rare AVOptions stay
/// at their defaults (the consumer can still write them through
/// `setAudioEffects` directly, the typed surface remains).
///
/// Pattern, illustrated on a single-knob filter:
///
/// ```dart
/// 'crystalizer': (p) {
///   final s = p.state.audioEffects.crystalizer;
///   void apply(CrystalizerSettings next) =>
///       p.updateAudioEffects((b) => b.copyWith(crystalizer: next));
///   return [
///     GenericKnobRow(
///       label: 'intensity',
///       value: s.i,
///       min: CrystalizerSettings.iMin,
///       max: CrystalizerSettings.iMax,
///       defaultValue: CrystalizerSettings.iDefault,
///       onChanged: (v) => apply(s.copyWith(i: v)),
///     ),
///   ];
/// },
/// ```
const Map<String, GenericFilterBuilder> genericFilterBuilders = {
  'acontrast': _acontrast,
  'adeclick': _adeclick,
  'adeclip': _adeclip,
  'adecorrelate': _adecorrelate,
  'adenorm': _adenorm,
  'adrc': _adrc,
  'adynamicsmooth': _adynamicsmooth,
  'aemphasis': _aemphasis,
  'aexciter': _aexciter,
  'afade': _afade,
  'afftdn': _afftdn,
  'afftfilt': _afftfilt,
  'afreqshift': _afreqshift,
  'afwtdn': _afwtdn,
  'aiir': _aiir,
  'anlmdn': _anlmdn,
  'allpass': _allpass,
  'apad': _apad,
  'aphaseshift': _aphaseshift,
  'apsyclip': _apsyclip,
  'aresample': _aresample,
  'arnndn': _arnndn,
  'asoftclip': _asoftclip,
  'asubboost': _asubboost,
  'asubcut': _asubcut,
  'asupercut': _asupercut,
  'asuperpass': _asuperpass,
  'asuperstop': _asuperstop,
  'atempo': _atempo,
  'atilt': _atilt,
  'bandpass': _bandpass,
  'bandreject': _bandreject,
  'bass': _bass,
  'biquad': _biquad,
  'compensationdelay': _compensationdelay,
  'crossfeed': _crossfeed,
  'crystalizer': _crystalizer,
  'dcshift': _dcshift,
  'dialoguenhance': _dialoguenhance,
  'drmeter': _drmeter,
  'dynaudnorm': _dynaudnorm,
  'extrastereo': _extrastereo,
  'haas': _haas,
  'hdcd': _hdcd,
  'highpass': _highpass,
  'highshelf': _highshelf,
  'lowpass': _lowpass,
  'lowshelf': _lowshelf,
  'rubberband': _rubberband,
  'silenceremove': _silenceremove,
  'speechnorm': _speechnorm,
  'stereowiden': _stereowiden,
  'surround': _surround,
  'tiltshelf': _tiltshelf,
  'treble': _treble,
  'virtualbass': _virtualbass,
};

// ──────────────────────────────────────────────────────────────────────
// Single-knob filters — the simplest shape: one primary parameter.
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _acontrast(Player p) {
  final s = p.state.audioEffects.acontrast;
  void apply(AcontrastSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(acontrast: next));
  return [
    GenericKnobRow(
      label: 'contrast',
      value: s.contrast,
      min: AcontrastSettings.contrastMin,
      max: AcontrastSettings.contrastMax,
      defaultValue: AcontrastSettings.contrastDefault,
      onChanged: (v) => apply(s.copyWith(contrast: v)),
    ),
  ];
}

List<GenericFilterRow> _adecorrelate(Player p) {
  final s = p.state.audioEffects.adecorrelate;
  void apply(AdecorrelateSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(adecorrelate: next));
  return [
    GenericKnobRow(
      label: 'stages',
      value: s.stages.toDouble(),
      min: AdecorrelateSettings.stagesMin.toDouble(),
      // parse.py reports `stagesMax` as missing; ffmpeg accepts up
      // to 16 stages in practice, more becomes inaudible. Hardcoded
      // fallback.
      max: 16,
      defaultValue: AdecorrelateSettings.stagesDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(stages: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
  ];
}

List<GenericFilterRow> _adenorm(Player p) {
  final s = p.state.audioEffects.adenorm;
  void apply(AdenormSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(adenorm: next));
  return [
    GenericKnobRow(
      label: 'level',
      value: s.level,
      min: AdenormSettings.levelMin,
      max: AdenormSettings.levelMax,
      defaultValue: AdenormSettings.levelDefault,
      onChanged: (v) => apply(s.copyWith(level: v)),
    ),
    GenericEnumRow<AdenormType>(
      label: 'type',
      value: s.type,
      options: AdenormType.values,
      onChanged: (v) => apply(s.copyWith(type: v)),
      format: (v) => v.name,
    ),
  ];
}

List<GenericFilterRow> _adrc(Player p) {
  final s = p.state.audioEffects.adrc;
  void apply(AdrcSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(adrc: next));
  return [
    GenericKnobRow(
      label: 'attack ms',
      value: s.attack,
      min: AdrcSettings.attackMin,
      max: AdrcSettings.attackMax,
      defaultValue: AdrcSettings.attackDefault,
      onChanged: (v) => apply(s.copyWith(attack: v)),
      format: (v) => v.toStringAsFixed(1),
    ),
    GenericKnobRow(
      label: 'release ms',
      value: s.release,
      min: AdrcSettings.releaseMin,
      max: AdrcSettings.releaseMax,
      defaultValue: AdrcSettings.releaseDefault,
      onChanged: (v) => apply(s.copyWith(release: v)),
      format: (v) => v.toStringAsFixed(1),
    ),
  ];
}

List<GenericFilterRow> _adynamicsmooth(Player p) {
  final s = p.state.audioEffects.adynamicsmooth;
  void apply(AdynamicsmoothSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(adynamicsmooth: next));
  return [
    GenericKnobRow(
      label: 'sensitivity',
      value: s.sensitivity,
      min: AdynamicsmoothSettings.sensitivityMin,
      max: AdynamicsmoothSettings.sensitivityMax,
      defaultValue: AdynamicsmoothSettings.sensitivityDefault,
      onChanged: (v) => apply(s.copyWith(sensitivity: v)),
    ),
    GenericKnobRow(
      label: 'basefreq',
      value: s.basefreq,
      min: AdynamicsmoothSettings.basefreqMin,
      max: AdynamicsmoothSettings.basefreqMax,
      defaultValue: AdynamicsmoothSettings.basefreqDefault,
      onChanged: (v) => apply(s.copyWith(basefreq: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
  ];
}

List<GenericFilterRow> _aemphasis(Player p) {
  final s = p.state.audioEffects.aemphasis;
  void apply(AemphasisSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(aemphasis: next));
  return [
    GenericEnumRow<AemphasisType>(
      label: 'type',
      value: s.type,
      options: AemphasisType.values,
      onChanged: (v) => apply(s.copyWith(type: v)),
      format: (v) => v.name,
    ),
    GenericEnumRow<AemphasisMode>(
      label: 'mode',
      value: s.mode,
      options: AemphasisMode.values,
      onChanged: (v) => apply(s.copyWith(mode: v)),
      format: (v) => v.name,
    ),
  ];
}

List<GenericFilterRow> _aexciter(Player p) {
  final s = p.state.audioEffects.aexciter;
  void apply(AexciterSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(aexciter: next));
  return [
    GenericKnobRow(
      label: 'amount',
      value: s.amount,
      min: AexciterSettings.amountMin,
      max: AexciterSettings.amountMax,
      defaultValue: AexciterSettings.amountDefault,
      onChanged: (v) => apply(s.copyWith(amount: v)),
    ),
    GenericKnobRow(
      label: 'drive',
      value: s.drive,
      min: AexciterSettings.driveMin,
      max: AexciterSettings.driveMax,
      defaultValue: AexciterSettings.driveDefault,
      onChanged: (v) => apply(s.copyWith(drive: v)),
    ),
    GenericKnobRow(
      label: 'blend',
      value: s.blend,
      min: AexciterSettings.blendMin,
      max: AexciterSettings.blendMax,
      defaultValue: AexciterSettings.blendDefault,
      onChanged: (v) => apply(s.copyWith(blend: v)),
    ),
    GenericKnobRow(
      label: 'freq',
      value: s.freq,
      min: AexciterSettings.freqMin,
      max: AexciterSettings.freqMax,
      defaultValue: AexciterSettings.freqDefault,
      onChanged: (v) => apply(s.copyWith(freq: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
  ];
}

List<GenericFilterRow> _afade(Player p) {
  final s = p.state.audioEffects.afade;
  void apply(AfadeSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(afade: next));
  return [
    GenericEnumRow<AfadeType>(
      label: 'type',
      value: s.type,
      options: AfadeType.values,
      onChanged: (v) => apply(s.copyWith(type: v)),
      format: (v) => v.name,
    ),
    GenericEnumRow<AfadeCurve>(
      label: 'curve',
      value: s.curve,
      options: AfadeCurve.values,
      onChanged: (v) => apply(s.copyWith(curve: v)),
      format: (v) => v.name,
    ),
  ];
}

List<GenericFilterRow> _afftdn(Player p) {
  final s = p.state.audioEffects.afftdn;
  void apply(AfftdnSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(afftdn: next));
  return [
    GenericKnobRow(
      label: 'noise reduction',
      value: s.nr,
      min: AfftdnSettings.nrMin,
      // `nrMax` not exposed by parse.py; ffmpeg accepts 0..97 dB.
      max: 97,
      defaultValue: AfftdnSettings.nrDefault,
      onChanged: (v) => apply(s.copyWith(nr: v)),
      format: (v) => '${v.toStringAsFixed(1)} dB',
    ),
    GenericKnobRow(
      label: 'noise floor',
      value: s.nf,
      min: AfftdnSettings.nfMin,
      max: AfftdnSettings.nfMax,
      defaultValue: AfftdnSettings.nfDefault,
      onChanged: (v) => apply(s.copyWith(nf: v)),
      format: (v) => '${v.toStringAsFixed(1)} dB',
    ),
    GenericKnobRow(
      label: 'adaptivity',
      value: s.adaptivity,
      min: AfftdnSettings.adaptivityMin,
      max: AfftdnSettings.adaptivityMax,
      defaultValue: AfftdnSettings.adaptivityDefault,
      onChanged: (v) => apply(s.copyWith(adaptivity: v)),
    ),
  ];
}

List<GenericFilterRow> _afreqshift(Player p) {
  final s = p.state.audioEffects.afreqshift;
  void apply(AfreqshiftSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(afreqshift: next));
  return [
    GenericKnobRow(
      label: 'shift Hz',
      value: s.shift,
      // parse.py misses shiftMin/Max for afreqshift; reasonable
      // musical range is ±1 kHz.
      min: -1000,
      max: 1000,
      defaultValue: AfreqshiftSettings.shiftDefault,
      onChanged: (v) => apply(s.copyWith(shift: v)),
      format: (v) => v.toStringAsFixed(1),
    ),
    GenericKnobRow(
      label: 'level',
      value: s.level,
      min: AfreqshiftSettings.levelMin,
      max: AfreqshiftSettings.levelMax,
      defaultValue: AfreqshiftSettings.levelDefault,
      onChanged: (v) => apply(s.copyWith(level: v)),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Biquad family — every filter exposes the same handful of params
// (frequency, width, gain for shelves, mix, normalize). One helper
// builds the row list given the field accessors.
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _allpass(Player p) {
  final s = p.state.audioEffects.allpass;
  void apply(AllpassSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(allpass: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: AllpassSettings.frequencyMin,
      max: AllpassSettings.frequencyMax,
      defaultValue: AllpassSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'width',
      value: s.width,
      min: AllpassSettings.widthMin,
      max: AllpassSettings.widthMax,
      defaultValue: AllpassSettings.widthDefault,
      onChanged: (v) => apply(s.copyWith(width: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: AllpassSettings.mixMin,
      max: AllpassSettings.mixMax,
      defaultValue: AllpassSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _bandpass(Player p) {
  final s = p.state.audioEffects.bandpass;
  void apply(BandpassSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(bandpass: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: BandpassSettings.frequencyMin,
      max: BandpassSettings.frequencyMax,
      defaultValue: BandpassSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'width',
      value: s.width,
      min: BandpassSettings.widthMin,
      max: BandpassSettings.widthMax,
      defaultValue: BandpassSettings.widthDefault,
      onChanged: (v) => apply(s.copyWith(width: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: BandpassSettings.mixMin,
      max: BandpassSettings.mixMax,
      defaultValue: BandpassSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _bandreject(Player p) {
  final s = p.state.audioEffects.bandreject;
  void apply(BandrejectSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(bandreject: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: BandrejectSettings.frequencyMin,
      max: BandrejectSettings.frequencyMax,
      defaultValue: BandrejectSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'width',
      value: s.width,
      min: BandrejectSettings.widthMin,
      max: BandrejectSettings.widthMax,
      defaultValue: BandrejectSettings.widthDefault,
      onChanged: (v) => apply(s.copyWith(width: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: BandrejectSettings.mixMin,
      max: BandrejectSettings.mixMax,
      defaultValue: BandrejectSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _bass(Player p) {
  final s = p.state.audioEffects.bass;
  void apply(BassSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(bass: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: BassSettings.frequencyMin,
      max: BassSettings.frequencyMax,
      defaultValue: BassSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'gain dB',
      value: s.gain,
      min: BassSettings.gainMin,
      max: BassSettings.gainMax,
      defaultValue: BassSettings.gainDefault,
      onChanged: (v) => apply(s.copyWith(gain: v)),
      format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
    ),
    GenericKnobRow(
      label: 'width',
      value: s.width,
      min: BassSettings.widthMin,
      max: BassSettings.widthMax,
      defaultValue: BassSettings.widthDefault,
      onChanged: (v) => apply(s.copyWith(width: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: BassSettings.mixMin,
      max: BassSettings.mixMax,
      defaultValue: BassSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _treble(Player p) {
  final s = p.state.audioEffects.treble;
  void apply(TrebleSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(treble: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: TrebleSettings.frequencyMin,
      max: TrebleSettings.frequencyMax,
      defaultValue: TrebleSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'gain dB',
      value: s.gain,
      min: TrebleSettings.gainMin,
      max: TrebleSettings.gainMax,
      defaultValue: TrebleSettings.gainDefault,
      onChanged: (v) => apply(s.copyWith(gain: v)),
      format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
    ),
    GenericKnobRow(
      label: 'width',
      value: s.width,
      min: TrebleSettings.widthMin,
      max: TrebleSettings.widthMax,
      defaultValue: TrebleSettings.widthDefault,
      onChanged: (v) => apply(s.copyWith(width: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: TrebleSettings.mixMin,
      max: TrebleSettings.mixMax,
      defaultValue: TrebleSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _lowshelf(Player p) {
  final s = p.state.audioEffects.lowshelf;
  void apply(LowshelfSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(lowshelf: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: LowshelfSettings.frequencyMin,
      max: LowshelfSettings.frequencyMax,
      defaultValue: LowshelfSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'gain dB',
      value: s.gain,
      min: LowshelfSettings.gainMin,
      max: LowshelfSettings.gainMax,
      defaultValue: LowshelfSettings.gainDefault,
      onChanged: (v) => apply(s.copyWith(gain: v)),
      format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: LowshelfSettings.mixMin,
      max: LowshelfSettings.mixMax,
      defaultValue: LowshelfSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _highshelf(Player p) {
  final s = p.state.audioEffects.highshelf;
  void apply(HighshelfSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(highshelf: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: HighshelfSettings.frequencyMin,
      max: HighshelfSettings.frequencyMax,
      defaultValue: HighshelfSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'gain dB',
      value: s.gain,
      min: HighshelfSettings.gainMin,
      max: HighshelfSettings.gainMax,
      defaultValue: HighshelfSettings.gainDefault,
      onChanged: (v) => apply(s.copyWith(gain: v)),
      format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: HighshelfSettings.mixMin,
      max: HighshelfSettings.mixMax,
      defaultValue: HighshelfSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _highpass(Player p) {
  final s = p.state.audioEffects.highpass;
  void apply(HighpassSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(highpass: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: HighpassSettings.frequencyMin,
      max: HighpassSettings.frequencyMax,
      defaultValue: HighpassSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'width',
      value: s.width,
      min: HighpassSettings.widthMin,
      max: HighpassSettings.widthMax,
      defaultValue: HighpassSettings.widthDefault,
      onChanged: (v) => apply(s.copyWith(width: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: HighpassSettings.mixMin,
      max: HighpassSettings.mixMax,
      defaultValue: HighpassSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _lowpass(Player p) {
  final s = p.state.audioEffects.lowpass;
  void apply(LowpassSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(lowpass: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: LowpassSettings.frequencyMin,
      max: LowpassSettings.frequencyMax,
      defaultValue: LowpassSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'width',
      value: s.width,
      min: LowpassSettings.widthMin,
      max: LowpassSettings.widthMax,
      defaultValue: LowpassSettings.widthDefault,
      onChanged: (v) => apply(s.copyWith(width: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: LowpassSettings.mixMin,
      max: LowpassSettings.mixMax,
      defaultValue: LowpassSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _tiltshelf(Player p) {
  final s = p.state.audioEffects.tiltshelf;
  void apply(TiltshelfSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(tiltshelf: next));
  return [
    GenericKnobRow(
      label: 'frequency',
      value: s.frequency,
      min: TiltshelfSettings.frequencyMin,
      max: TiltshelfSettings.frequencyMax,
      defaultValue: TiltshelfSettings.frequencyDefault,
      onChanged: (v) => apply(s.copyWith(frequency: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'gain dB',
      value: s.gain,
      min: TiltshelfSettings.gainMin,
      max: TiltshelfSettings.gainMax,
      defaultValue: TiltshelfSettings.gainDefault,
      onChanged: (v) => apply(s.copyWith(gain: v)),
      format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: TiltshelfSettings.mixMin,
      max: TiltshelfSettings.mixMax,
      defaultValue: TiltshelfSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

List<GenericFilterRow> _biquad(Player p) {
  // biquad is the raw 6-coefficient filter; there's no musical
  // shorthand to surface beyond `mix`. Power users editing the
  // coefficients tend to do it via `setAudioEffects` directly.
  final s = p.state.audioEffects.biquad;
  void apply(BiquadSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(biquad: next));
  return [
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: BiquadSettings.mixMin,
      max: BiquadSettings.mixMax,
      defaultValue: BiquadSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Sub / super filters — Chebyshev / Butterworth single-stage filters
// for sub-bass and supersonic shaping.
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _asubcut(Player p) {
  final s = p.state.audioEffects.asubcut;
  void apply(AsubcutSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(asubcut: next));
  return [
    GenericKnobRow(
      label: 'cutoff',
      value: s.cutoff,
      min: AsubcutSettings.cutoffMin,
      max: AsubcutSettings.cutoffMax,
      defaultValue: AsubcutSettings.cutoffDefault,
      onChanged: (v) => apply(s.copyWith(cutoff: v)),
      format: (v) => v.toStringAsFixed(1),
    ),
    GenericKnobRow(
      label: 'order',
      value: s.order.toDouble(),
      min: AsubcutSettings.orderMin.toDouble(),
      max: AsubcutSettings.orderMax.toDouble(),
      defaultValue: AsubcutSettings.orderDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(order: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'level',
      value: s.level,
      min: AsubcutSettings.levelMin,
      max: AsubcutSettings.levelMax,
      defaultValue: AsubcutSettings.levelDefault,
      onChanged: (v) => apply(s.copyWith(level: v)),
    ),
  ];
}

List<GenericFilterRow> _asupercut(Player p) {
  final s = p.state.audioEffects.asupercut;
  void apply(AsupercutSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(asupercut: next));
  return [
    GenericKnobRow(
      label: 'cutoff',
      value: s.cutoff,
      min: AsupercutSettings.cutoffMin,
      max: AsupercutSettings.cutoffMax,
      defaultValue: AsupercutSettings.cutoffDefault,
      onChanged: (v) => apply(s.copyWith(cutoff: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'order',
      value: s.order.toDouble(),
      min: AsupercutSettings.orderMin.toDouble(),
      max: AsupercutSettings.orderMax.toDouble(),
      defaultValue: AsupercutSettings.orderDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(order: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'level',
      value: s.level,
      min: AsupercutSettings.levelMin,
      max: AsupercutSettings.levelMax,
      defaultValue: AsupercutSettings.levelDefault,
      onChanged: (v) => apply(s.copyWith(level: v)),
    ),
  ];
}

List<GenericFilterRow> _asuperpass(Player p) {
  final s = p.state.audioEffects.asuperpass;
  void apply(AsuperpassSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(asuperpass: next));
  return [
    GenericKnobRow(
      label: 'centerf',
      value: s.centerf,
      min: AsuperpassSettings.centerfMin,
      max: AsuperpassSettings.centerfMax,
      defaultValue: AsuperpassSettings.centerfDefault,
      onChanged: (v) => apply(s.copyWith(centerf: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'order',
      value: s.order.toDouble(),
      min: AsuperpassSettings.orderMin.toDouble(),
      max: AsuperpassSettings.orderMax.toDouble(),
      defaultValue: AsuperpassSettings.orderDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(order: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'qfactor',
      value: s.qfactor,
      min: AsuperpassSettings.qfactorMin,
      max: AsuperpassSettings.qfactorMax,
      defaultValue: AsuperpassSettings.qfactorDefault,
      onChanged: (v) => apply(s.copyWith(qfactor: v)),
    ),
  ];
}

List<GenericFilterRow> _asuperstop(Player p) {
  final s = p.state.audioEffects.asuperstop;
  void apply(AsuperstopSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(asuperstop: next));
  return [
    GenericKnobRow(
      label: 'centerf',
      value: s.centerf,
      min: AsuperstopSettings.centerfMin,
      max: AsuperstopSettings.centerfMax,
      defaultValue: AsuperstopSettings.centerfDefault,
      onChanged: (v) => apply(s.copyWith(centerf: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'order',
      value: s.order.toDouble(),
      min: AsuperstopSettings.orderMin.toDouble(),
      max: AsuperstopSettings.orderMax.toDouble(),
      defaultValue: AsuperstopSettings.orderDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(order: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'qfactor',
      value: s.qfactor,
      min: AsuperstopSettings.qfactorMin,
      max: AsuperstopSettings.qfactorMax,
      defaultValue: AsuperstopSettings.qfactorDefault,
      onChanged: (v) => apply(s.copyWith(qfactor: v)),
    ),
  ];
}

List<GenericFilterRow> _asubboost(Player p) {
  final s = p.state.audioEffects.asubboost;
  void apply(AsubboostSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(asubboost: next));
  return [
    GenericKnobRow(
      label: 'cutoff',
      value: s.cutoff,
      min: AsubboostSettings.cutoffMin,
      max: AsubboostSettings.cutoffMax,
      defaultValue: AsubboostSettings.cutoffDefault,
      onChanged: (v) => apply(s.copyWith(cutoff: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'boost',
      value: s.boost,
      min: AsubboostSettings.boostMin,
      max: AsubboostSettings.boostMax,
      defaultValue: AsubboostSettings.boostDefault,
      onChanged: (v) => apply(s.copyWith(boost: v)),
    ),
    GenericKnobRow(
      label: 'feedback',
      value: s.feedback,
      min: AsubboostSettings.feedbackMin,
      max: AsubboostSettings.feedbackMax,
      defaultValue: AsubboostSettings.feedbackDefault,
      onChanged: (v) => apply(s.copyWith(feedback: v)),
    ),
  ];
}

List<GenericFilterRow> _atilt(Player p) {
  final s = p.state.audioEffects.atilt;
  void apply(AtiltSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(atilt: next));
  return [
    GenericKnobRow(
      label: 'freq',
      value: s.freq,
      min: AtiltSettings.freqMin,
      max: AtiltSettings.freqMax,
      defaultValue: AtiltSettings.freqDefault,
      onChanged: (v) => apply(s.copyWith(freq: v)),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'slope',
      value: s.slope,
      min: AtiltSettings.slopeMin,
      max: AtiltSettings.slopeMax,
      defaultValue: AtiltSettings.slopeDefault,
      onChanged: (v) => apply(s.copyWith(slope: v)),
    ),
    GenericKnobRow(
      label: 'level',
      value: s.level,
      min: AtiltSettings.levelMin,
      max: AtiltSettings.levelMax,
      defaultValue: AtiltSettings.levelDefault,
      onChanged: (v) => apply(s.copyWith(level: v)),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Restoration / denoise / clipping
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _apsyclip(Player p) {
  final s = p.state.audioEffects.apsyclip;
  void apply(ApsyclipSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(apsyclip: next));
  return [
    GenericKnobRow(
      label: 'clip',
      value: s.clip,
      min: ApsyclipSettings.clipMin,
      max: 1, // parse.py misses clipMax; lavfi caps at 1.0

      defaultValue: ApsyclipSettings.clipDefault,
      onChanged: (v) => apply(s.copyWith(clip: v)),
    ),
    GenericKnobRow(
      label: 'iterations',
      value: s.iterations.toDouble(),
      min: ApsyclipSettings.iterationsMin.toDouble(),
      max: ApsyclipSettings.iterationsMax.toDouble(),
      defaultValue: ApsyclipSettings.iterationsDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(iterations: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
  ];
}

List<GenericFilterRow> _asoftclip(Player p) {
  final s = p.state.audioEffects.asoftclip;
  void apply(AsoftclipSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(asoftclip: next));
  return [
    GenericKnobRow(
      label: 'threshold',
      value: s.threshold,
      min: AsoftclipSettings.thresholdMin,
      max: AsoftclipSettings.thresholdMax,
      defaultValue: AsoftclipSettings.thresholdDefault,
      onChanged: (v) => apply(s.copyWith(threshold: v)),
    ),
    GenericKnobRow(
      label: 'output',
      value: s.output,
      min: AsoftclipSettings.outputMin,
      max: AsoftclipSettings.outputMax,
      defaultValue: AsoftclipSettings.outputDefault,
      onChanged: (v) => apply(s.copyWith(output: v)),
    ),
  ];
}

List<GenericFilterRow> _arnndn(Player p) {
  final s = p.state.audioEffects.arnndn;
  void apply(ArnndnSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(arnndn: next));
  return [
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: ArnndnSettings.mixMin,
      max: ArnndnSettings.mixMax,
      defaultValue: ArnndnSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Stereo / spatial
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _crossfeed(Player p) {
  final s = p.state.audioEffects.crossfeed;
  void apply(CrossfeedSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(crossfeed: next));
  return [
    GenericKnobRow(
      label: 'strength',
      value: s.strength,
      min: CrossfeedSettings.strengthMin,
      max: CrossfeedSettings.strengthMax,
      defaultValue: CrossfeedSettings.strengthDefault,
      onChanged: (v) => apply(s.copyWith(strength: v)),
    ),
    GenericKnobRow(
      label: 'range',
      value: s.range,
      min: CrossfeedSettings.rangeMin,
      max: CrossfeedSettings.rangeMax,
      defaultValue: CrossfeedSettings.rangeDefault,
      onChanged: (v) => apply(s.copyWith(range: v)),
    ),
    GenericKnobRow(
      label: 'slope',
      value: s.slope,
      min: CrossfeedSettings.slopeMin,
      max: 1, // parse.py misses slopeMax; lavfi accepts 0..1

      defaultValue: CrossfeedSettings.slopeDefault,
      onChanged: (v) => apply(s.copyWith(slope: v)),
    ),
  ];
}

List<GenericFilterRow> _extrastereo(Player p) {
  final s = p.state.audioEffects.extrastereo;
  void apply(ExtrastereoSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(extrastereo: next));
  return [
    GenericKnobRow(
      label: 'mult',
      value: s.m,
      min: ExtrastereoSettings.mMin,
      max: ExtrastereoSettings.mMax,
      defaultValue: ExtrastereoSettings.mDefault,
      onChanged: (v) => apply(s.copyWith(m: v)),
    ),
  ];
}

List<GenericFilterRow> _stereowiden(Player p) {
  final s = p.state.audioEffects.stereowiden;
  void apply(StereowidenSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(stereowiden: next));
  return [
    GenericKnobRow(
      label: 'feedback',
      value: s.feedback,
      min: StereowidenSettings.feedbackMin,
      max: StereowidenSettings.feedbackMax,
      defaultValue: StereowidenSettings.feedbackDefault,
      onChanged: (v) => apply(s.copyWith(feedback: v)),
    ),
    GenericKnobRow(
      label: 'crossfeed',
      value: s.crossfeed,
      min: StereowidenSettings.crossfeedMin,
      max: StereowidenSettings.crossfeedMax,
      defaultValue: StereowidenSettings.crossfeedDefault,
      onChanged: (v) => apply(s.copyWith(crossfeed: v)),
    ),
    GenericKnobRow(
      label: 'drymix',
      value: s.drymix,
      min: StereowidenSettings.drymixMin,
      max: StereowidenSettings.drymixMax,
      defaultValue: StereowidenSettings.drymixDefault,
      onChanged: (v) => apply(s.copyWith(drymix: v)),
    ),
  ];
}

List<GenericFilterRow> _haas(Player p) {
  final s = p.state.audioEffects.haas;
  void apply(HaasSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(haas: next));
  return [
    GenericKnobRow(
      label: 'left delay ms',
      value: s.left_delay,
      // parse.py misses left_delayMax; haas accepts 0..40 ms.
      min: HaasSettings.left_delayMin,
      max: 40,
      defaultValue: HaasSettings.left_delayDefault,
      onChanged: (v) => apply(s.copyWith(left_delay: v)),
      format: (v) => v.toStringAsFixed(1),
    ),
    GenericKnobRow(
      label: 'right delay ms',
      value: s.right_delay,
      min: HaasSettings.right_delayMin,
      max: 40, // see left_delay note above.

      defaultValue: HaasSettings.right_delayDefault,
      onChanged: (v) => apply(s.copyWith(right_delay: v)),
      format: (v) => v.toStringAsFixed(1),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Single-knob enhancers / utilities
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _crystalizer(Player p) {
  final s = p.state.audioEffects.crystalizer;
  void apply(CrystalizerSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(crystalizer: next));
  return [
    GenericKnobRow(
      label: 'intensity',
      value: s.i,
      min: CrystalizerSettings.iMin,
      max: CrystalizerSettings.iMax,
      defaultValue: CrystalizerSettings.iDefault,
      onChanged: (v) => apply(s.copyWith(i: v)),
    ),
  ];
}

List<GenericFilterRow> _dcshift(Player p) {
  final s = p.state.audioEffects.dcshift;
  void apply(DcshiftSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(dcshift: next));
  return [
    GenericKnobRow(
      label: 'shift',
      value: s.shift,
      min: DcshiftSettings.shiftMin,
      max: DcshiftSettings.shiftMax,
      defaultValue: DcshiftSettings.shiftDefault,
      onChanged: (v) => apply(s.copyWith(shift: v)),
    ),
  ];
}

List<GenericFilterRow> _dialoguenhance(Player p) {
  final s = p.state.audioEffects.dialoguenhance;
  void apply(DialoguenhanceSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(dialoguenhance: next));
  return [
    GenericKnobRow(
      label: 'voice',
      value: s.voice,
      min: DialoguenhanceSettings.voiceMin,
      max: DialoguenhanceSettings.voiceMax,
      defaultValue: DialoguenhanceSettings.voiceDefault,
      onChanged: (v) => apply(s.copyWith(voice: v)),
    ),
    GenericKnobRow(
      label: 'enhance',
      value: s.enhance,
      min: DialoguenhanceSettings.enhanceMin,
      max: DialoguenhanceSettings.enhanceMax,
      defaultValue: DialoguenhanceSettings.enhanceDefault,
      onChanged: (v) => apply(s.copyWith(enhance: v)),
    ),
    GenericKnobRow(
      label: 'original',
      value: s.original,
      min: DialoguenhanceSettings.originalMin,
      max: DialoguenhanceSettings.originalMax,
      defaultValue: DialoguenhanceSettings.originalDefault,
      onChanged: (v) => apply(s.copyWith(original: v)),
    ),
  ];
}

List<GenericFilterRow> _drmeter(Player p) {
  final s = p.state.audioEffects.drmeter;
  void apply(DrmeterSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(drmeter: next));
  return [
    GenericKnobRow(
      label: 'length',
      value: s.length,
      min: DrmeterSettings.lengthMin,
      max: DrmeterSettings.lengthMax,
      defaultValue: DrmeterSettings.lengthDefault,
      onChanged: (v) => apply(s.copyWith(length: v)),
      format: (v) => '${v.toStringAsFixed(1)} s',
    ),
  ];
}

List<GenericFilterRow> _virtualbass(Player p) {
  final s = p.state.audioEffects.virtualbass;
  void apply(VirtualbassSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(virtualbass: next));
  return [
    GenericKnobRow(
      label: 'cutoff',
      value: s.cutoff,
      min: VirtualbassSettings.cutoffMin,
      max: VirtualbassSettings.cutoffMax,
      defaultValue: VirtualbassSettings.cutoffDefault,
      onChanged: (v) => apply(s.copyWith(cutoff: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'strength',
      value: s.strength,
      min: VirtualbassSettings.strengthMin,
      max: VirtualbassSettings.strengthMax,
      defaultValue: VirtualbassSettings.strengthDefault,
      onChanged: (v) => apply(s.copyWith(strength: v)),
    ),
  ];
}

List<GenericFilterRow> _surround(Player p) {
  // surround has 30+ params; surface only the most impactful ones.
  final s = p.state.audioEffects.surround;
  void apply(SurroundSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(surround: next));
  return [
    GenericKnobRow(
      label: 'angle',
      value: s.angle,
      min: SurroundSettings.angleMin,
      max: SurroundSettings.angleMax,
      defaultValue: SurroundSettings.angleDefault,
      onChanged: (v) => apply(s.copyWith(angle: v)),
      format: (v) => '${v.toStringAsFixed(0)}°',
    ),
    GenericKnobRow(
      label: 'level in',
      value: s.level_in,
      min: SurroundSettings.level_inMin,
      max: SurroundSettings.level_inMax,
      defaultValue: SurroundSettings.level_inDefault,
      onChanged: (v) => apply(s.copyWith(level_in: v)),
    ),
    GenericKnobRow(
      label: 'level out',
      value: s.level_out,
      min: SurroundSettings.level_outMin,
      max: SurroundSettings.level_outMax,
      defaultValue: SurroundSettings.level_outDefault,
      onChanged: (v) => apply(s.copyWith(level_out: v)),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Time / format / utility
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _atempo(Player p) {
  final s = p.state.audioEffects.atempo;
  void apply(AtempoSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(atempo: next));
  return [
    GenericKnobRow(
      label: 'tempo',
      value: s.tempo,
      // parse.py misses tempoMin/Max; lavfi atempo accepts 0.5..100.
      min: 0.5,
      max: 4,
      defaultValue: AtempoSettings.tempoDefault,
      onChanged: (v) => apply(s.copyWith(tempo: v)),
      format: (v) => '${v.toStringAsFixed(2)}×',
    ),
  ];
}

List<GenericFilterRow> _aresample(Player p) {
  final s = p.state.audioEffects.aresample;
  void apply(AresampleSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(aresample: next));
  return [
    GenericKnobRow(
      label: 'sample rate',
      value: s.sample_rate.toDouble(),
      min: AresampleSettings.sample_rateMin.toDouble(),
      max: 96000,
      defaultValue: AresampleSettings.sample_rateDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(sample_rate: v.round())),
      format: (v) =>
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
    ),
  ];
}

List<GenericFilterRow> _apad(Player p) {
  final s = p.state.audioEffects.apad;
  void apply(ApadSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(apad: next));
  return [
    GenericKnobRow(
      label: 'packet size',
      value: s.packet_size.toDouble(),
      min: ApadSettings.packet_sizeMin.toDouble(),
      max: 65536,
      defaultValue: ApadSettings.packet_sizeDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(packet_size: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
  ];
}

List<GenericFilterRow> _aphaseshift(Player p) {
  final s = p.state.audioEffects.aphaseshift;
  void apply(AphaseshiftSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(aphaseshift: next));
  return [
    GenericKnobRow(
      label: 'shift',
      value: s.shift,
      min: AphaseshiftSettings.shiftMin,
      max: AphaseshiftSettings.shiftMax,
      defaultValue: AphaseshiftSettings.shiftDefault,
      onChanged: (v) => apply(s.copyWith(shift: v)),
    ),
    GenericKnobRow(
      label: 'order',
      value: s.order.toDouble(),
      // parse.py misses orderMax; reasonable cap is 16.
      min: AphaseshiftSettings.orderMin.toDouble(),
      max: 16,
      defaultValue: AphaseshiftSettings.orderDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(order: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
  ];
}

List<GenericFilterRow> _compensationdelay(Player p) {
  final s = p.state.audioEffects.compensationdelay;
  void apply(CompensationdelaySettings next) =>
      p.updateAudioEffects((b) => b.copyWith(compensationdelay: next));
  return [
    GenericKnobRow(
      label: 'mm',
      value: s.mm.toDouble(),
      min: CompensationdelaySettings.mmMin.toDouble(),
      max: CompensationdelaySettings.mmMax.toDouble(),
      defaultValue: CompensationdelaySettings.mmDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(mm: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'cm',
      value: s.cm.toDouble(),
      min: CompensationdelaySettings.cmMin.toDouble(),
      max: CompensationdelaySettings.cmMax.toDouble(),
      defaultValue: CompensationdelaySettings.cmDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(cm: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'm',
      value: s.m.toDouble(),
      min: CompensationdelaySettings.mMin.toDouble(),
      max: CompensationdelaySettings.mMax.toDouble(),
      defaultValue: CompensationdelaySettings.mDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(m: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Silence / fades / dynamics
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _silenceremove(Player p) {
  final s = p.state.audioEffects.silenceremove;
  void apply(SilenceremoveSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(silenceremove: next));
  return [
    GenericKnobRow(
      label: 'start thr',
      value: s.start_threshold,
      // parse.py misses start_thresholdMax; 0..1 linear amplitude.
      min: SilenceremoveSettings.start_thresholdMin,
      max: 1,
      defaultValue: SilenceremoveSettings.start_thresholdDefault,
      onChanged: (v) => apply(s.copyWith(start_threshold: v)),
    ),
    GenericKnobRow(
      label: 'stop thr',
      value: s.stop_threshold,
      // see start_threshold note above.
      min: SilenceremoveSettings.stop_thresholdMin,
      max: 1,
      defaultValue: SilenceremoveSettings.stop_thresholdDefault,
      onChanged: (v) => apply(s.copyWith(stop_threshold: v)),
    ),
  ];
}

List<GenericFilterRow> _dynaudnorm(Player p) {
  final s = p.state.audioEffects.dynaudnorm;
  void apply(DynaudnormSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(dynaudnorm: next));
  return [
    GenericKnobRow(
      label: 'compress',
      value: s.compress,
      min: DynaudnormSettings.compressMin,
      max: DynaudnormSettings.compressMax,
      defaultValue: DynaudnormSettings.compressDefault,
      onChanged: (v) => apply(s.copyWith(compress: v)),
    ),
    GenericKnobRow(
      label: 'threshold',
      value: s.threshold,
      min: DynaudnormSettings.thresholdMin,
      max: DynaudnormSettings.thresholdMax,
      defaultValue: DynaudnormSettings.thresholdDefault,
      onChanged: (v) => apply(s.copyWith(threshold: v)),
    ),
  ];
}

List<GenericFilterRow> _speechnorm(Player p) {
  final s = p.state.audioEffects.speechnorm;
  void apply(SpeechnormSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(speechnorm: next));
  return [
    GenericKnobRow(
      label: 'compression',
      value: s.compression,
      min: SpeechnormSettings.compressionMin,
      max: SpeechnormSettings.compressionMax,
      defaultValue: SpeechnormSettings.compressionDefault,
      onChanged: (v) => apply(s.copyWith(compression: v)),
    ),
    GenericKnobRow(
      label: 'expansion',
      value: s.expansion,
      min: SpeechnormSettings.expansionMin,
      max: SpeechnormSettings.expansionMax,
      defaultValue: SpeechnormSettings.expansionDefault,
      onChanged: (v) => apply(s.copyWith(expansion: v)),
    ),
  ];
}

// ──────────────────────────────────────────────────────────────────────
// Pitch / time
// ──────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────
// Restoration / DSP — declick / declip / spectral / wavelet / NLM
// ──────────────────────────────────────────────────────────────────────

List<GenericFilterRow> _adeclick(Player p) {
  final s = p.state.audioEffects.adeclick;
  void apply(AdeclickSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(adeclick: next));
  return [
    GenericKnobRow(
      label: 'window ms',
      value: s.window,
      min: AdeclickSettings.windowMin,
      max: AdeclickSettings.windowMax,
      defaultValue: AdeclickSettings.windowDefault,
      onChanged: (v) => apply(s.copyWith(window: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'overlap %',
      value: s.overlap,
      min: AdeclickSettings.overlapMin,
      max: AdeclickSettings.overlapMax,
      defaultValue: AdeclickSettings.overlapDefault,
      onChanged: (v) => apply(s.copyWith(overlap: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'threshold',
      value: s.threshold,
      min: AdeclickSettings.thresholdMin,
      max: AdeclickSettings.thresholdMax,
      defaultValue: AdeclickSettings.thresholdDefault,
      onChanged: (v) => apply(s.copyWith(threshold: v)),
    ),
    GenericKnobRow(
      label: 'burst',
      value: s.burst,
      min: AdeclickSettings.burstMin,
      max: AdeclickSettings.burstMax,
      defaultValue: AdeclickSettings.burstDefault,
      onChanged: (v) => apply(s.copyWith(burst: v)),
    ),
    GenericEnumRow<AdeclickM>(
      label: 'method',
      value: s.method,
      options: AdeclickM.values,
      onChanged: (v) => apply(s.copyWith(method: v)),
      format: (v) => v.name,
    ),
  ];
}

List<GenericFilterRow> _adeclip(Player p) {
  final s = p.state.audioEffects.adeclip;
  void apply(AdeclipSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(adeclip: next));
  return [
    GenericKnobRow(
      label: 'window ms',
      value: s.window,
      min: AdeclipSettings.windowMin,
      max: AdeclipSettings.windowMax,
      defaultValue: AdeclipSettings.windowDefault,
      onChanged: (v) => apply(s.copyWith(window: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'overlap %',
      value: s.overlap,
      min: AdeclipSettings.overlapMin,
      max: AdeclipSettings.overlapMax,
      defaultValue: AdeclipSettings.overlapDefault,
      onChanged: (v) => apply(s.copyWith(overlap: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'threshold',
      value: s.threshold,
      min: AdeclipSettings.thresholdMin,
      max: AdeclipSettings.thresholdMax,
      defaultValue: AdeclipSettings.thresholdDefault,
      onChanged: (v) => apply(s.copyWith(threshold: v)),
    ),
    GenericKnobRow(
      label: 'history',
      value: s.hsize.toDouble(),
      min: AdeclipSettings.hsizeMin.toDouble(),
      max: AdeclipSettings.hsizeMax.toDouble(),
      defaultValue: AdeclipSettings.hsizeDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(hsize: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericEnumRow<AdeclipM>(
      label: 'method',
      value: s.method,
      options: AdeclipM.values,
      onChanged: (v) => apply(s.copyWith(method: v)),
      format: (v) => v.name,
    ),
  ];
}

List<GenericFilterRow> _afftfilt(Player p) {
  // FFT-domain filter — `imag` / `real` are math expressions (Tier C);
  // surface only the FFT engine knobs.
  final s = p.state.audioEffects.afftfilt;
  void apply(AfftfiltSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(afftfilt: next));
  return [
    GenericKnobRow(
      label: 'win size',
      value: s.win_size.toDouble(),
      min: AfftfiltSettings.win_sizeMin.toDouble(),
      max: 16384,
      defaultValue: AfftfiltSettings.win_sizeDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(win_size: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'overlap',
      value: s.overlap,
      min: AfftfiltSettings.overlapMin,
      max: AfftfiltSettings.overlapMax,
      defaultValue: AfftfiltSettings.overlapDefault,
      onChanged: (v) => apply(s.copyWith(overlap: v)),
    ),
  ];
}

List<GenericFilterRow> _afwtdn(Player p) {
  final s = p.state.audioEffects.afwtdn;
  void apply(AfwtdnSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(afwtdn: next));
  return [
    GenericKnobRow(
      label: 'sigma',
      value: s.sigma,
      min: AfwtdnSettings.sigmaMin,
      max: AfwtdnSettings.sigmaMax,
      defaultValue: AfwtdnSettings.sigmaDefault,
      onChanged: (v) => apply(s.copyWith(sigma: v)),
    ),
    GenericKnobRow(
      label: 'levels',
      value: s.levels.toDouble(),
      min: AfwtdnSettings.levelsMin.toDouble(),
      max: 16, // parse.py misses levelsMax
      defaultValue: AfwtdnSettings.levelsDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(levels: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'percent',
      value: s.percent,
      min: AfwtdnSettings.percentMin,
      max: AfwtdnSettings.percentMax,
      defaultValue: AfwtdnSettings.percentDefault,
      onChanged: (v) => apply(s.copyWith(percent: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'softness',
      value: s.softness,
      min: AfwtdnSettings.softnessMin,
      max: AfwtdnSettings.softnessMax,
      defaultValue: AfwtdnSettings.softnessDefault,
      onChanged: (v) => apply(s.copyWith(softness: v)),
    ),
    GenericToggleRow(
      label: 'adaptive',
      value: s.adaptive,
      onChanged: (v) => apply(s.copyWith(adaptive: v)),
    ),
    GenericToggleRow(
      label: 'profile',
      value: s.profile,
      onChanged: (v) => apply(s.copyWith(profile: v)),
    ),
  ];
}

List<GenericFilterRow> _aiir(Player p) {
  // Typed knobs cover the common dry/mix/wet + channel selector;
  // the IIR coefficient editing happens through `AiirChannelsX`
  // (consumer-side typed list) since it doesn't fit a single knob.
  final s = p.state.audioEffects.aiir;
  void apply(AiirSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(aiir: next));
  return [
    GenericKnobRow(
      label: 'channel',
      value: s.channel.toDouble(),
      min: AiirSettings.channelMin.toDouble(),
      max: 8, // typical max channels for music; spec allows up to 1024
      defaultValue: AiirSettings.channelDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(channel: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericKnobRow(
      label: 'dry',
      value: s.dry,
      min: AiirSettings.dryMin,
      max: AiirSettings.dryMax,
      defaultValue: AiirSettings.dryDefault,
      onChanged: (v) => apply(s.copyWith(dry: v)),
    ),
    GenericKnobRow(
      label: 'wet',
      value: s.wet,
      min: AiirSettings.wetMin,
      max: AiirSettings.wetMax,
      defaultValue: AiirSettings.wetDefault,
      onChanged: (v) => apply(s.copyWith(wet: v)),
    ),
    GenericKnobRow(
      label: 'mix',
      value: s.mix,
      min: AiirSettings.mixMin,
      max: AiirSettings.mixMax,
      defaultValue: AiirSettings.mixDefault,
      onChanged: (v) => apply(s.copyWith(mix: v)),
    ),
    GenericToggleRow(
      label: 'normalize',
      value: s.normalize,
      onChanged: (v) => apply(s.copyWith(normalize: v)),
    ),
  ];
}

List<GenericFilterRow> _anlmdn(Player p) {
  final s = p.state.audioEffects.anlmdn;
  void apply(AnlmdnSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(anlmdn: next));
  return [
    GenericKnobRow(
      label: 'strength',
      value: s.strength,
      min: 0.001,
      max: 100, // spec range is huge; tighten to musical
      defaultValue: AnlmdnSettings.strengthDefault,
      onChanged: (v) => apply(s.copyWith(strength: v)),
    ),
    GenericKnobRow(
      label: 'smooth',
      value: s.smooth,
      min: AnlmdnSettings.smoothMin,
      max: AnlmdnSettings.smoothMax,
      defaultValue: AnlmdnSettings.smoothDefault,
      onChanged: (v) => apply(s.copyWith(smooth: v)),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericEnumRow<AnlmdnMode>(
      label: 'output',
      value: s.output,
      options: AnlmdnMode.values,
      onChanged: (v) => apply(s.copyWith(output: v)),
      format: (v) => v.name,
    ),
  ];
}

List<GenericFilterRow> _hdcd(Player p) {
  final s = p.state.audioEffects.hdcd;
  void apply(HdcdSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(hdcd: next));
  return [
    GenericEnumRow<HdcdAnalyzeMode>(
      label: 'analyze',
      value: s.analyze_mode,
      options: HdcdAnalyzeMode.values,
      onChanged: (v) => apply(s.copyWith(analyze_mode: v)),
      format: (v) => v.name,
    ),
    GenericEnumRow<HdcdBitsPerSample>(
      label: 'bits',
      value: s.bits_per_sample,
      options: HdcdBitsPerSample.values,
      onChanged: (v) => apply(s.copyWith(bits_per_sample: v)),
      format: (v) => v.name,
    ),
    GenericKnobRow(
      label: 'cdt ms',
      value: s.cdt_ms.toDouble(),
      min: HdcdSettings.cdt_msMin.toDouble(),
      max: HdcdSettings.cdt_msMax.toDouble(),
      defaultValue: HdcdSettings.cdt_msDefault.toDouble(),
      onChanged: (v) => apply(s.copyWith(cdt_ms: v.round())),
      format: (v) => v.toStringAsFixed(0),
    ),
    GenericToggleRow(
      label: 'process stereo',
      value: s.process_stereo,
      onChanged: (v) => apply(s.copyWith(process_stereo: v)),
    ),
    GenericToggleRow(
      label: 'force pe',
      value: s.force_pe,
      onChanged: (v) => apply(s.copyWith(force_pe: v)),
    ),
  ];
}

List<GenericFilterRow> _rubberband(Player p) {
  final s = p.state.audioEffects.rubberband;
  void apply(RubberbandSettings next) =>
      p.updateAudioEffects((b) => b.copyWith(rubberband: next));
  return [
    GenericKnobRow(
      label: 'tempo',
      value: s.tempo,
      min: RubberbandSettings.tempoMin,
      max: RubberbandSettings.tempoMax,
      defaultValue: RubberbandSettings.tempoDefault,
      onChanged: (v) => apply(s.copyWith(tempo: v)),
      format: (v) => '${v.toStringAsFixed(2)}×',
    ),
    GenericKnobRow(
      label: 'pitch',
      value: s.pitch,
      min: RubberbandSettings.pitchMin,
      max: RubberbandSettings.pitchMax,
      defaultValue: RubberbandSettings.pitchDefault,
      onChanged: (v) => apply(s.copyWith(pitch: v)),
      format: (v) => '${v.toStringAsFixed(2)}×',
    ),
  ];
}
