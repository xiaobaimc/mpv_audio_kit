// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.
//
// AUTO-GENERATED — do not edit by hand.

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../../shared/property_cards.dart';

import '../../widgets/superequalizer_widget.dart';
import '../../widgets/extension_editors.dart';

/// Filters in the **Equalization & tone** category. Each card maps to a typed
/// `*Settings` field on the [AudioEffects] bundle.
class FiltersEqualizationPage extends StatefulWidget {
  final Player player;
  const FiltersEqualizationPage({super.key, required this.player});

  @override
  State<FiltersEqualizationPage> createState() =>
      _FiltersEqualizationPageState();
}

class _FiltersEqualizationPageState extends State<FiltersEqualizationPage> {
  Player get player => widget.player;

  Stream<T> _watch<T>(T Function(AudioEffects) sel) =>
      player.stream.audioEffects.map(sel).distinct();

  String _f(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SuperequalizerWidget(player: player),
        StreamBuilder<AnequalizerSettings>(
          stream: _watch((e) => e.anequalizer),
          initialData: player.state.audioEffects.anequalizer,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'anequalizer',
              subtitle: 'lavfi-anequalizer',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(anequalizer: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamTextField(
                  label: 'colors',
                  value: s.colors,
                  defaultValue:
                      '"red|green|blue|yellow|orange|lime|pink|magenta|brown"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(anequalizer: s.copyWith(colors: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'curves',
                  value: s.curves,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(anequalizer: s.copyWith(curves: v)),
                  ),
                ),
                FilterParamDropdown<AnequalizerFscale>(
                  label: 'fscale',
                  value: s.fscale,
                  defaultValue: AnequalizerFscale.log,
                  options: const [AnequalizerFscale.lin, AnequalizerFscale.log],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(anequalizer: s.copyWith(fscale: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'mgain',
                  value: s.mgain,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 60.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(anequalizer: s.copyWith(mgain: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'size',
                  value: s.size,
                  defaultValue: '"hd720"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(anequalizer: s.copyWith(size: v)),
                  ),
                ),
                AnequalizerBandsEditor(player: player, settings: s),
              ],
            );
          },
        ),
        StreamBuilder<AsubboostSettings>(
          stream: _watch((e) => e.asubboost),
          initialData: player.state.audioEffects.asubboost,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'asubboost',
              subtitle: 'lavfi-asubboost',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(asubboost: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'boost',
                  value: s.boost,
                  min: 1.0,
                  max: 12.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubboost: s.copyWith(boost: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubboost: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'cutoff',
                  value: s.cutoff,
                  min: 50.0,
                  max: 900.0,
                  defaultValue: 100.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubboost: s.copyWith(cutoff: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'decay',
                  value: s.decay,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubboost: s.copyWith(decay: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'delay',
                  value: s.delay,
                  min: 1.0,
                  max: 100.0,
                  defaultValue: 20.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubboost: s.copyWith(delay: v)),
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
                    (e) => e.copyWith(asubboost: s.copyWith(dry: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'feedback',
                  value: s.feedback,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.9,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubboost: s.copyWith(feedback: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'slope',
                  value: s.slope,
                  min: 0.0001,
                  max: 1.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubboost: s.copyWith(slope: v)),
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
                    (e) => e.copyWith(asubboost: s.copyWith(wet: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AtiltSettings>(
          stream: _watch((e) => e.atilt),
          initialData: player.state.audioEffects.atilt,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'atilt',
              subtitle: 'lavfi-atilt',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(atilt: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'freq',
                  value: s.freq,
                  min: 20.0,
                  max: 192000.0,
                  defaultValue: 10000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(atilt: s.copyWith(freq: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level',
                  value: s.level,
                  min: 0.0,
                  max: 4.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(atilt: s.copyWith(level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'order',
                  value: s.order.toDouble(),
                  min: 2.0,
                  max: 30.0,
                  defaultValue: 5.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(atilt: s.copyWith(order: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'slope',
                  value: s.slope,
                  min: -1.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(atilt: s.copyWith(slope: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 100.0,
                  max: 10000.0,
                  defaultValue: 1000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(atilt: s.copyWith(width: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<BassSettings>(
          stream: _watch((e) => e.bass),
          initialData: player.state.audioEffects.bass,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'bass',
              subtitle: 'lavfi-bass',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(bass: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<BassTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: BassTransformType.di,
                  options: const [
                    BassTransformType.di,
                    BassTransformType.dii,
                    BassTransformType.tdi,
                    BassTransformType.tdii,
                    BassTransformType.latt,
                    BassTransformType.svf,
                    BassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(a: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b',
                  value: s.b.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(b: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'blocksize',
                  value: s.blocksize.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 100.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'frequency',
                  value: s.frequency,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 100.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(frequency: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'g',
                  value: s.g,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(g: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'gain',
                  value: s.gain,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(m: v)),
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
                    (e) => e.copyWith(bass: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'p',
                  value: s.p.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(p: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'poles',
                  value: s.poles.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(poles: v.round())),
                  ),
                ),
                FilterParamDropdown<BassPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: BassPrecision.auto,
                  options: const [
                    BassPrecision.auto,
                    BassPrecision.s16,
                    BassPrecision.s32,
                    BassPrecision.f32,
                    BassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<BassPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: BassPrecision.auto,
                  options: const [
                    BassPrecision.auto,
                    BassPrecision.s16,
                    BassPrecision.s32,
                    BassPrecision.f32,
                    BassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<BassWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: BassWidthType.q,
                  options: const [
                    BassWidthType.h,
                    BassWidthType.q,
                    BassWidthType.o,
                    BassWidthType.s,
                    BassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<BassTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: BassTransformType.di,
                  options: const [
                    BassTransformType.di,
                    BassTransformType.dii,
                    BassTransformType.tdi,
                    BassTransformType.tdii,
                    BassTransformType.latt,
                    BassTransformType.svf,
                    BassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<BassWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: BassWidthType.q,
                  options: const [
                    BassWidthType.h,
                    BassWidthType.q,
                    BassWidthType.o,
                    BassWidthType.s,
                    BassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bass: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<BiquadSettings>(
          stream: _watch((e) => e.biquad),
          initialData: player.state.audioEffects.biquad,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'biquad',
              subtitle: 'lavfi-biquad',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(biquad: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<BiquadTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: BiquadTransformType.di,
                  options: const [
                    BiquadTransformType.di,
                    BiquadTransformType.dii,
                    BiquadTransformType.tdi,
                    BiquadTransformType.tdii,
                    BiquadTransformType.latt,
                    BiquadTransformType.svf,
                    BiquadTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(a: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'a0',
                  value: s.a0,
                  min: -2147483648.0,
                  max: 2147483647.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(a0: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'a1',
                  value: s.a1,
                  min: -2147483648.0,
                  max: 2147483647.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(a1: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'a2',
                  value: s.a2,
                  min: -2147483648.0,
                  max: 2147483647.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(a2: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b',
                  value: s.b.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(b: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'b0',
                  value: s.b0,
                  min: -2147483648.0,
                  max: 2147483647.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(b0: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b1',
                  value: s.b1,
                  min: -2147483648.0,
                  max: 2147483647.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(b1: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b2',
                  value: s.b2,
                  min: -2147483648.0,
                  max: 2147483647.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(b2: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'blocksize',
                  value: s.blocksize.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(m: v)),
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
                    (e) => e.copyWith(biquad: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamDropdown<BiquadPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: BiquadPrecision.auto,
                  options: const [
                    BiquadPrecision.auto,
                    BiquadPrecision.s16,
                    BiquadPrecision.s32,
                    BiquadPrecision.f32,
                    BiquadPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<BiquadPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: BiquadPrecision.auto,
                  options: const [
                    BiquadPrecision.auto,
                    BiquadPrecision.s16,
                    BiquadPrecision.s32,
                    BiquadPrecision.f32,
                    BiquadPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<BiquadTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: BiquadTransformType.di,
                  options: const [
                    BiquadTransformType.di,
                    BiquadTransformType.dii,
                    BiquadTransformType.tdi,
                    BiquadTransformType.tdii,
                    BiquadTransformType.latt,
                    BiquadTransformType.svf,
                    BiquadTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(biquad: s.copyWith(transform: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<EqualizerSettings>(
          stream: _watch((e) => e.equalizer),
          initialData: player.state.audioEffects.equalizer,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'equalizer',
              subtitle: 'lavfi-equalizer',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(equalizer: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<EqualizerTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: EqualizerTransformType.di,
                  options: const [
                    EqualizerTransformType.di,
                    EqualizerTransformType.dii,
                    EqualizerTransformType.tdi,
                    EqualizerTransformType.tdii,
                    EqualizerTransformType.latt,
                    EqualizerTransformType.svf,
                    EqualizerTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(a: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b',
                  value: s.b.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(b: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'blocksize',
                  value: s.blocksize.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(equalizer: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'frequency',
                  value: s.frequency,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(frequency: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'g',
                  value: s.g,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(g: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'gain',
                  value: s.gain,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(m: v)),
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
                    (e) => e.copyWith(equalizer: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamDropdown<EqualizerPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: EqualizerPrecision.auto,
                  options: const [
                    EqualizerPrecision.auto,
                    EqualizerPrecision.s16,
                    EqualizerPrecision.s32,
                    EqualizerPrecision.f32,
                    EqualizerPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<EqualizerPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: EqualizerPrecision.auto,
                  options: const [
                    EqualizerPrecision.auto,
                    EqualizerPrecision.s16,
                    EqualizerPrecision.s32,
                    EqualizerPrecision.f32,
                    EqualizerPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<EqualizerWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: EqualizerWidthType.q,
                  options: const [
                    EqualizerWidthType.h,
                    EqualizerWidthType.q,
                    EqualizerWidthType.o,
                    EqualizerWidthType.s,
                    EqualizerWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<EqualizerTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: EqualizerTransformType.di,
                  options: const [
                    EqualizerTransformType.di,
                    EqualizerTransformType.dii,
                    EqualizerTransformType.tdi,
                    EqualizerTransformType.tdii,
                    EqualizerTransformType.latt,
                    EqualizerTransformType.svf,
                    EqualizerTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<EqualizerWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: EqualizerWidthType.q,
                  options: const [
                    EqualizerWidthType.h,
                    EqualizerWidthType.q,
                    EqualizerWidthType.o,
                    EqualizerWidthType.s,
                    EqualizerWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(equalizer: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<FirequalizerSettings>(
          stream: _watch((e) => e.firequalizer),
          initialData: player.state.audioEffects.firequalizer,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'firequalizer',
              subtitle: 'lavfi-firequalizer',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(firequalizer: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'accuracy',
                  value: s.accuracy,
                  min: 0.0,
                  max: 1e10,
                  defaultValue: 5.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(accuracy: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'delay',
                  value: s.delay,
                  min: 0.0,
                  max: 1e10,
                  defaultValue: 0.01,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(delay: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'dumpfile',
                  value: s.dumpfile,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(dumpfile: v)),
                  ),
                ),
                FilterParamDropdown<FirequalizerScale>(
                  label: 'dumpscale',
                  value: s.dumpscale,
                  defaultValue: FirequalizerScale.linlog,
                  options: const [
                    FirequalizerScale.linlin,
                    FirequalizerScale.linlog,
                    FirequalizerScale.loglin,
                    FirequalizerScale.loglog,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(dumpscale: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'fft2',
                  value: s.fft2,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(fft2: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'fixed',
                  value: s.fixed,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(fixed: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'gain',
                  value: s.gain,
                  defaultValue: '"gain_interpolate(f)"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'gain_entry',
                  value: s.gain_entry,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(gain_entry: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'min_phase',
                  value: s.min_phase,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(min_phase: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'multi',
                  value: s.multi,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(multi: v)),
                  ),
                ),
                FilterParamDropdown<FirequalizerScale>(
                  label: 'scale',
                  value: s.scale,
                  defaultValue: FirequalizerScale.linlog,
                  options: const [
                    FirequalizerScale.linlin,
                    FirequalizerScale.linlog,
                    FirequalizerScale.loglin,
                    FirequalizerScale.loglog,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(scale: v)),
                  ),
                ),
                FilterParamDropdown<FirequalizerWfunc>(
                  label: 'wfunc',
                  value: s.wfunc,
                  defaultValue: FirequalizerWfunc.hann,
                  options: const [
                    FirequalizerWfunc.rectangular,
                    FirequalizerWfunc.hann,
                    FirequalizerWfunc.hamming,
                    FirequalizerWfunc.blackman,
                    FirequalizerWfunc.nuttall3,
                    FirequalizerWfunc.mnuttall3,
                    FirequalizerWfunc.nuttall,
                    FirequalizerWfunc.bnuttall,
                    FirequalizerWfunc.bharris,
                    FirequalizerWfunc.tukey,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(wfunc: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'zero_phase',
                  value: s.zero_phase,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(firequalizer: s.copyWith(zero_phase: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<HighshelfSettings>(
          stream: _watch((e) => e.highshelf),
          initialData: player.state.audioEffects.highshelf,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'highshelf',
              subtitle: 'lavfi-highshelf',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(highshelf: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<HighshelfTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: HighshelfTransformType.di,
                  options: const [
                    HighshelfTransformType.di,
                    HighshelfTransformType.dii,
                    HighshelfTransformType.tdi,
                    HighshelfTransformType.tdii,
                    HighshelfTransformType.latt,
                    HighshelfTransformType.svf,
                    HighshelfTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(a: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b',
                  value: s.b.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(b: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'blocksize',
                  value: s.blocksize.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(highshelf: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 3000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'frequency',
                  value: s.frequency,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 3000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(frequency: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'g',
                  value: s.g,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(g: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'gain',
                  value: s.gain,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(m: v)),
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
                    (e) => e.copyWith(highshelf: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'p',
                  value: s.p.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(p: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'poles',
                  value: s.poles.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(poles: v.round())),
                  ),
                ),
                FilterParamDropdown<HighshelfPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: HighshelfPrecision.auto,
                  options: const [
                    HighshelfPrecision.auto,
                    HighshelfPrecision.s16,
                    HighshelfPrecision.s32,
                    HighshelfPrecision.f32,
                    HighshelfPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<HighshelfPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: HighshelfPrecision.auto,
                  options: const [
                    HighshelfPrecision.auto,
                    HighshelfPrecision.s16,
                    HighshelfPrecision.s32,
                    HighshelfPrecision.f32,
                    HighshelfPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<HighshelfWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: HighshelfWidthType.q,
                  options: const [
                    HighshelfWidthType.h,
                    HighshelfWidthType.q,
                    HighshelfWidthType.o,
                    HighshelfWidthType.s,
                    HighshelfWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<HighshelfTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: HighshelfTransformType.di,
                  options: const [
                    HighshelfTransformType.di,
                    HighshelfTransformType.dii,
                    HighshelfTransformType.tdi,
                    HighshelfTransformType.tdii,
                    HighshelfTransformType.latt,
                    HighshelfTransformType.svf,
                    HighshelfTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<HighshelfWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: HighshelfWidthType.q,
                  options: const [
                    HighshelfWidthType.h,
                    HighshelfWidthType.q,
                    HighshelfWidthType.o,
                    HighshelfWidthType.s,
                    HighshelfWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highshelf: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<LowshelfSettings>(
          stream: _watch((e) => e.lowshelf),
          initialData: player.state.audioEffects.lowshelf,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'lowshelf',
              subtitle: 'lavfi-lowshelf',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(lowshelf: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<LowshelfTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: LowshelfTransformType.di,
                  options: const [
                    LowshelfTransformType.di,
                    LowshelfTransformType.dii,
                    LowshelfTransformType.tdi,
                    LowshelfTransformType.tdii,
                    LowshelfTransformType.latt,
                    LowshelfTransformType.svf,
                    LowshelfTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(a: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b',
                  value: s.b.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(b: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'blocksize',
                  value: s.blocksize.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(lowshelf: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 100.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'frequency',
                  value: s.frequency,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 100.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(frequency: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'g',
                  value: s.g,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(g: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'gain',
                  value: s.gain,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(m: v)),
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
                    (e) => e.copyWith(lowshelf: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'p',
                  value: s.p.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(p: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'poles',
                  value: s.poles.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(poles: v.round())),
                  ),
                ),
                FilterParamDropdown<LowshelfPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: LowshelfPrecision.auto,
                  options: const [
                    LowshelfPrecision.auto,
                    LowshelfPrecision.s16,
                    LowshelfPrecision.s32,
                    LowshelfPrecision.f32,
                    LowshelfPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<LowshelfPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: LowshelfPrecision.auto,
                  options: const [
                    LowshelfPrecision.auto,
                    LowshelfPrecision.s16,
                    LowshelfPrecision.s32,
                    LowshelfPrecision.f32,
                    LowshelfPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<LowshelfWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: LowshelfWidthType.q,
                  options: const [
                    LowshelfWidthType.h,
                    LowshelfWidthType.q,
                    LowshelfWidthType.o,
                    LowshelfWidthType.s,
                    LowshelfWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<LowshelfTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: LowshelfTransformType.di,
                  options: const [
                    LowshelfTransformType.di,
                    LowshelfTransformType.dii,
                    LowshelfTransformType.tdi,
                    LowshelfTransformType.tdii,
                    LowshelfTransformType.latt,
                    LowshelfTransformType.svf,
                    LowshelfTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<LowshelfWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: LowshelfWidthType.q,
                  options: const [
                    LowshelfWidthType.h,
                    LowshelfWidthType.q,
                    LowshelfWidthType.o,
                    LowshelfWidthType.s,
                    LowshelfWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowshelf: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<TiltshelfSettings>(
          stream: _watch((e) => e.tiltshelf),
          initialData: player.state.audioEffects.tiltshelf,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'tiltshelf',
              subtitle: 'lavfi-tiltshelf',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(tiltshelf: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<TiltshelfTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: TiltshelfTransformType.di,
                  options: const [
                    TiltshelfTransformType.di,
                    TiltshelfTransformType.dii,
                    TiltshelfTransformType.tdi,
                    TiltshelfTransformType.tdii,
                    TiltshelfTransformType.latt,
                    TiltshelfTransformType.svf,
                    TiltshelfTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(a: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b',
                  value: s.b.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(b: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'blocksize',
                  value: s.blocksize.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(tiltshelf: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 3000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'frequency',
                  value: s.frequency,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 3000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(frequency: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'g',
                  value: s.g,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(g: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'gain',
                  value: s.gain,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(m: v)),
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
                    (e) => e.copyWith(tiltshelf: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'p',
                  value: s.p.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(p: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'poles',
                  value: s.poles.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(poles: v.round())),
                  ),
                ),
                FilterParamDropdown<TiltshelfPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: TiltshelfPrecision.auto,
                  options: const [
                    TiltshelfPrecision.auto,
                    TiltshelfPrecision.s16,
                    TiltshelfPrecision.s32,
                    TiltshelfPrecision.f32,
                    TiltshelfPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<TiltshelfPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: TiltshelfPrecision.auto,
                  options: const [
                    TiltshelfPrecision.auto,
                    TiltshelfPrecision.s16,
                    TiltshelfPrecision.s32,
                    TiltshelfPrecision.f32,
                    TiltshelfPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<TiltshelfWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: TiltshelfWidthType.q,
                  options: const [
                    TiltshelfWidthType.h,
                    TiltshelfWidthType.q,
                    TiltshelfWidthType.o,
                    TiltshelfWidthType.s,
                    TiltshelfWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<TiltshelfTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: TiltshelfTransformType.di,
                  options: const [
                    TiltshelfTransformType.di,
                    TiltshelfTransformType.dii,
                    TiltshelfTransformType.tdi,
                    TiltshelfTransformType.tdii,
                    TiltshelfTransformType.latt,
                    TiltshelfTransformType.svf,
                    TiltshelfTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<TiltshelfWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: TiltshelfWidthType.q,
                  options: const [
                    TiltshelfWidthType.h,
                    TiltshelfWidthType.q,
                    TiltshelfWidthType.o,
                    TiltshelfWidthType.s,
                    TiltshelfWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(tiltshelf: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<TrebleSettings>(
          stream: _watch((e) => e.treble),
          initialData: player.state.audioEffects.treble,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'treble',
              subtitle: 'lavfi-treble',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(treble: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<TrebleTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: TrebleTransformType.di,
                  options: const [
                    TrebleTransformType.di,
                    TrebleTransformType.dii,
                    TrebleTransformType.tdi,
                    TrebleTransformType.tdii,
                    TrebleTransformType.latt,
                    TrebleTransformType.svf,
                    TrebleTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(a: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'b',
                  value: s.b.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(b: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'blocksize',
                  value: s.blocksize.toDouble(),
                  min: 0.0,
                  max: 32768.0,
                  defaultValue: 0.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 3000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'frequency',
                  value: s.frequency,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 3000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(frequency: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'g',
                  value: s.g,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(g: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'gain',
                  value: s.gain,
                  min: -900.0,
                  max: 900.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(m: v)),
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
                    (e) => e.copyWith(treble: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'p',
                  value: s.p.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(p: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'poles',
                  value: s.poles.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(poles: v.round())),
                  ),
                ),
                FilterParamDropdown<TreblePrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: TreblePrecision.auto,
                  options: const [
                    TreblePrecision.auto,
                    TreblePrecision.s16,
                    TreblePrecision.s32,
                    TreblePrecision.f32,
                    TreblePrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<TreblePrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: TreblePrecision.auto,
                  options: const [
                    TreblePrecision.auto,
                    TreblePrecision.s16,
                    TreblePrecision.s32,
                    TreblePrecision.f32,
                    TreblePrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<TrebleWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: TrebleWidthType.q,
                  options: const [
                    TrebleWidthType.h,
                    TrebleWidthType.q,
                    TrebleWidthType.o,
                    TrebleWidthType.s,
                    TrebleWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<TrebleTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: TrebleTransformType.di,
                  options: const [
                    TrebleTransformType.di,
                    TrebleTransformType.dii,
                    TrebleTransformType.tdi,
                    TrebleTransformType.tdii,
                    TrebleTransformType.latt,
                    TrebleTransformType.svf,
                    TrebleTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<TrebleWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: TrebleWidthType.q,
                  options: const [
                    TrebleWidthType.h,
                    TrebleWidthType.q,
                    TrebleWidthType.o,
                    TrebleWidthType.s,
                    TrebleWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(treble: s.copyWith(width_type: v)),
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
