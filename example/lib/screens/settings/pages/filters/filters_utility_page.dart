// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.
//
// AUTO-GENERATED — do not edit by hand.

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../../shared/property_cards.dart';

/// Filters in the **Analysis, fade & utilities** category. Each card maps to a typed
/// `*Settings` field on the [AudioEffects] bundle.
class FiltersUtilityPage extends StatefulWidget {
  final Player player;
  const FiltersUtilityPage({super.key, required this.player});

  @override
  State<FiltersUtilityPage> createState() => _FiltersUtilityPageState();
}

class _FiltersUtilityPageState extends State<FiltersUtilityPage> {
  Player get player => widget.player;

  Stream<T> _watch<T>(T Function(AudioEffects) sel) =>
      player.stream.audioEffects.map(sel).distinct();

  String _f(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<AfftfiltSettings>(
          stream: _watch((e) => e.afftfilt),
          initialData: player.state.audioEffects.afftfilt,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'afftfilt',
              subtitle: 'lavfi-afftfilt',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(afftfilt: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamTextField(
                  label: 'imag',
                  value: s.imag,
                  defaultValue: '"im"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afftfilt: s.copyWith(imag: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'overlap',
                  value: s.overlap,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.75,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afftfilt: s.copyWith(overlap: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'real',
                  value: s.real,
                  defaultValue: '"re"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afftfilt: s.copyWith(real: v)),
                  ),
                ),
                FilterParamDropdown<AfftfiltWinFunc>(
                  label: 'win_func',
                  value: s.win_func,
                  defaultValue: AfftfiltWinFunc.hann,
                  options: const [
                    AfftfiltWinFunc.rect,
                    AfftfiltWinFunc.bartlett,
                    AfftfiltWinFunc.hann,
                    AfftfiltWinFunc.hanning,
                    AfftfiltWinFunc.hamming,
                    AfftfiltWinFunc.blackman,
                    AfftfiltWinFunc.welch,
                    AfftfiltWinFunc.flattop,
                    AfftfiltWinFunc.bharris,
                    AfftfiltWinFunc.bnuttall,
                    AfftfiltWinFunc.bhann,
                    AfftfiltWinFunc.sine,
                    AfftfiltWinFunc.nuttall,
                    AfftfiltWinFunc.lanczos,
                    AfftfiltWinFunc.gauss,
                    AfftfiltWinFunc.tukey,
                    AfftfiltWinFunc.dolph,
                    AfftfiltWinFunc.cauchy,
                    AfftfiltWinFunc.parzen,
                    AfftfiltWinFunc.poisson,
                    AfftfiltWinFunc.bohman,
                    AfftfiltWinFunc.kaiser,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afftfilt: s.copyWith(win_func: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'win_size',
                  value: s.win_size.toDouble(),
                  min: 16.0,
                  max: 131072.0,
                  defaultValue: 4096.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(afftfilt: s.copyWith(win_size: v.round())),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AiirSettings>(
          stream: _watch((e) => e.aiir),
          initialData: player.state.audioEffects.aiir,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'aiir',
              subtitle: 'lavfi-aiir',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(aiir: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'channel',
                  value: s.channel.toDouble(),
                  min: 0.0,
                  max: 1024.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(channel: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'dry',
                  value: s.dry,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(dry: v)),
                  ),
                ),
                FilterParamDropdown<AiirPrecision>(
                  label: 'e',
                  value: s.e,
                  defaultValue: AiirPrecision.dbl,
                  options: const [
                    AiirPrecision.dbl,
                    AiirPrecision.flt,
                    AiirPrecision.i32,
                    AiirPrecision.i16,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(e: v)),
                  ),
                ),
                FilterParamDropdown<AiirFormat>(
                  label: 'f',
                  value: s.f,
                  defaultValue: AiirFormat.zp,
                  options: const [
                    AiirFormat.ll,
                    AiirFormat.sf,
                    AiirFormat.tf,
                    AiirFormat.zp,
                    AiirFormat.pr,
                    AiirFormat.pd,
                    AiirFormat.sp,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(f: v)),
                  ),
                ),
                FilterParamDropdown<AiirFormat>(
                  label: 'format',
                  value: s.format,
                  defaultValue: AiirFormat.zp,
                  options: const [
                    AiirFormat.ll,
                    AiirFormat.sf,
                    AiirFormat.tf,
                    AiirFormat.zp,
                    AiirFormat.pr,
                    AiirFormat.pd,
                    AiirFormat.sp,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(format: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'gains',
                  value: s.gains,
                  defaultValue: '"1|1"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(gains: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'k',
                  value: s.k,
                  defaultValue: '"1|1"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(k: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'mix',
                  value: s.mix,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: true,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: true,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'p',
                  value: s.p,
                  defaultValue: '"1+0i 1-0i"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(p: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'poles',
                  value: s.poles,
                  defaultValue: '"1+0i 1-0i"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(poles: v)),
                  ),
                ),
                FilterParamDropdown<AiirPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: AiirPrecision.dbl,
                  options: const [
                    AiirPrecision.dbl,
                    AiirPrecision.flt,
                    AiirPrecision.i32,
                    AiirPrecision.i16,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<AiirProcess>(
                  label: 'process',
                  value: s.process,
                  defaultValue: AiirProcess.s,
                  options: const [AiirProcess.d, AiirProcess.s, AiirProcess.p],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(process: v)),
                  ),
                ),
                FilterParamDropdown<AiirProcess>(
                  label: 'r',
                  value: s.r,
                  defaultValue: AiirProcess.s,
                  options: const [AiirProcess.d, AiirProcess.s, AiirProcess.p],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(r: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'rate',
                  value: s.rate,
                  defaultValue: '"25"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(rate: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'response',
                  value: s.response,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(response: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'size',
                  value: s.size,
                  defaultValue: '"hd720"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(size: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'wet',
                  value: s.wet,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(wet: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'z',
                  value: s.z,
                  defaultValue: '"1+0i 1-0i"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(z: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'zeros',
                  value: s.zeros,
                  defaultValue: '"1+0i 1-0i"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aiir: s.copyWith(zeros: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AfadeSettings>(
          stream: _watch((e) => e.afade),
          initialData: player.state.audioEffects.afade,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'afade',
              subtitle: 'lavfi-afade',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(afade: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<AfadeCurve>(
                  label: 'c',
                  value: s.c,
                  defaultValue: AfadeCurve.tri,
                  options: const [
                    AfadeCurve.nofade,
                    AfadeCurve.tri,
                    AfadeCurve.qsin,
                    AfadeCurve.esin,
                    AfadeCurve.hsin,
                    AfadeCurve.log,
                    AfadeCurve.ipar,
                    AfadeCurve.qua,
                    AfadeCurve.cub,
                    AfadeCurve.squ,
                    AfadeCurve.cbr,
                    AfadeCurve.par,
                    AfadeCurve.exp,
                    AfadeCurve.iqsin,
                    AfadeCurve.ihsin,
                    AfadeCurve.dese,
                    AfadeCurve.desi,
                    AfadeCurve.losi,
                    AfadeCurve.sinc,
                    AfadeCurve.isinc,
                    AfadeCurve.quat,
                    AfadeCurve.quatr,
                    AfadeCurve.qsin2,
                    AfadeCurve.hsin2,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(c: v)),
                  ),
                ),
                FilterParamDropdown<AfadeCurve>(
                  label: 'curve',
                  value: s.curve,
                  defaultValue: AfadeCurve.tri,
                  options: const [
                    AfadeCurve.nofade,
                    AfadeCurve.tri,
                    AfadeCurve.qsin,
                    AfadeCurve.esin,
                    AfadeCurve.hsin,
                    AfadeCurve.log,
                    AfadeCurve.ipar,
                    AfadeCurve.qua,
                    AfadeCurve.cub,
                    AfadeCurve.squ,
                    AfadeCurve.cbr,
                    AfadeCurve.par,
                    AfadeCurve.exp,
                    AfadeCurve.iqsin,
                    AfadeCurve.ihsin,
                    AfadeCurve.dese,
                    AfadeCurve.desi,
                    AfadeCurve.losi,
                    AfadeCurve.sinc,
                    AfadeCurve.isinc,
                    AfadeCurve.quat,
                    AfadeCurve.quatr,
                    AfadeCurve.qsin2,
                    AfadeCurve.hsin2,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(curve: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'nb_samples',
                  value: s.nb_samples.toDouble(),
                  min: 1.0,
                  max: 9223372036854775807.0,
                  defaultValue: 44100.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(nb_samples: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'ns',
                  value: s.ns.toDouble(),
                  min: 1.0,
                  max: 9223372036854775807.0,
                  defaultValue: 44100.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(ns: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'silence',
                  value: s.silence,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(silence: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'ss',
                  value: s.ss.toDouble(),
                  min: 0.0,
                  max: 9223372036854775807.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(ss: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'start_sample',
                  value: s.start_sample.toDouble(),
                  min: 0.0,
                  max: 9223372036854775807.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(afade: s.copyWith(start_sample: v.round())),
                  ),
                ),
                FilterParamDropdown<AfadeType>(
                  label: 't',
                  value: s.t,
                  defaultValue: AfadeType.in_,
                  options: const [AfadeType.in_, AfadeType.out],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<AfadeType>(
                  label: 'type',
                  value: s.type,
                  defaultValue: AfadeType.in_,
                  options: const [AfadeType.in_, AfadeType.out],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(type: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'unity',
                  value: s.unity,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(afade: s.copyWith(unity: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<ApadSettings>(
          stream: _watch((e) => e.apad),
          initialData: player.state.audioEffects.apad,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'apad',
              subtitle: 'lavfi-apad',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(apad: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'packet_size',
                  value: s.packet_size.toDouble(),
                  min: 0.0,
                  max: 2147483647.0,
                  defaultValue: 4096.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apad: s.copyWith(packet_size: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'pad_len',
                  value: s.pad_len.toDouble(),
                  min: -1.0,
                  max: 9223372036854775807.0,
                  defaultValue: -1.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apad: s.copyWith(pad_len: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'whole_len',
                  value: s.whole_len.toDouble(),
                  min: -1.0,
                  max: 9223372036854775807.0,
                  defaultValue: -1.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apad: s.copyWith(whole_len: v.round())),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<SilenceremoveSettings>(
          stream: _watch((e) => e.silenceremove),
          initialData: player.state.audioEffects.silenceremove,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'silenceremove',
              subtitle: 'lavfi-silenceremove',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(silenceremove: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<SilenceremoveDetection>(
                  label: 'detection',
                  value: s.detection,
                  defaultValue: SilenceremoveDetection.rms,
                  options: const [
                    SilenceremoveDetection.avg,
                    SilenceremoveDetection.rms,
                    SilenceremoveDetection.peak,
                    SilenceremoveDetection.median,
                    SilenceremoveDetection.ptp,
                    SilenceremoveDetection.dev,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(silenceremove: s.copyWith(detection: v)),
                  ),
                ),
                FilterParamDropdown<SilenceremoveMode>(
                  label: 'start_mode',
                  value: s.start_mode,
                  defaultValue: SilenceremoveMode.any,
                  options: const [SilenceremoveMode.any, SilenceremoveMode.all],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(silenceremove: s.copyWith(start_mode: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'start_periods',
                  value: s.start_periods.toDouble(),
                  min: 0.0,
                  max: 9000.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      silenceremove: s.copyWith(start_periods: v.round()),
                    ),
                  ),
                ),
                FilterParamSlider(
                  label: 'start_threshold',
                  value: s.start_threshold,
                  min: 0.0,
                  max: 1.7976931348623157e+308,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      silenceremove: s.copyWith(start_threshold: v),
                    ),
                  ),
                ),
                FilterParamDropdown<SilenceremoveMode>(
                  label: 'stop_mode',
                  value: s.stop_mode,
                  defaultValue: SilenceremoveMode.all,
                  options: const [SilenceremoveMode.any, SilenceremoveMode.all],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(silenceremove: s.copyWith(stop_mode: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'stop_periods',
                  value: s.stop_periods.toDouble(),
                  min: -9000.0,
                  max: 9000.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      silenceremove: s.copyWith(stop_periods: v.round()),
                    ),
                  ),
                ),
                FilterParamSlider(
                  label: 'stop_threshold',
                  value: s.stop_threshold,
                  min: 0.0,
                  max: 1.7976931348623157e+308,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      silenceremove: s.copyWith(stop_threshold: v),
                    ),
                  ),
                ),
                FilterParamDropdown<SilenceremoveTimestamp>(
                  label: 'timestamp',
                  value: s.timestamp,
                  defaultValue: SilenceremoveTimestamp.write,
                  options: const [
                    SilenceremoveTimestamp.write,
                    SilenceremoveTimestamp.copy,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(silenceremove: s.copyWith(timestamp: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AevalSettings>(
          stream: _watch((e) => e.aeval),
          initialData: player.state.audioEffects.aeval,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'aeval',
              subtitle: 'lavfi-aeval',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(aeval: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aeval: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channel_layout',
                  value: s.channel_layout,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aeval: s.copyWith(channel_layout: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'exprs',
                  value: s.exprs,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aeval: s.copyWith(exprs: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AformatSettings>(
          stream: _watch((e) => e.aformat),
          initialData: player.state.audioEffects.aformat,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'aformat',
              subtitle: 'lavfi-aformat',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(aformat: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamTextField(
                  label: 'channel_layouts',
                  value: s.channel_layouts,
                  defaultValue: '',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aformat: s.copyWith(channel_layouts: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'cl',
                  value: s.cl,
                  defaultValue: '',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aformat: s.copyWith(cl: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'f',
                  value: s.f,
                  defaultValue: '',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aformat: s.copyWith(f: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'r',
                  value: s.r,
                  defaultValue: '',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aformat: s.copyWith(r: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'sample_fmts',
                  value: s.sample_fmts,
                  defaultValue: '',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aformat: s.copyWith(sample_fmts: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'sample_rates',
                  value: s.sample_rates,
                  defaultValue: '',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(aformat: s.copyWith(sample_rates: v)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
