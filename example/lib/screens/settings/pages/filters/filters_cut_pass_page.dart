// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.
//
// AUTO-GENERATED — do not edit by hand.

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../../shared/property_cards.dart';

/// Filters in the **Filters (cut / pass)** category. Each card maps to a typed
/// `*Settings` field on the [AudioEffects] bundle.
class FiltersCutPassPage extends StatefulWidget {
  final Player player;
  const FiltersCutPassPage({super.key, required this.player});

  @override
  State<FiltersCutPassPage> createState() => _FiltersCutPassPageState();
}

class _FiltersCutPassPageState extends State<FiltersCutPassPage> {
  Player get player => widget.player;

  Stream<T> _watch<T>(T Function(AudioEffects) sel) =>
      player.stream.audioEffects.map(sel).distinct();

  String _f(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<AllpassSettings>(
          stream: _watch((e) => e.allpass),
          initialData: player.state.audioEffects.allpass,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'allpass',
              subtitle: 'lavfi-allpass',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(allpass: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<AllpassTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: AllpassTransformType.di,
                  options: const [
                    AllpassTransformType.di,
                    AllpassTransformType.dii,
                    AllpassTransformType.tdi,
                    AllpassTransformType.tdii,
                    AllpassTransformType.latt,
                    AllpassTransformType.svf,
                    AllpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(a: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(channels: v)),
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
                    (e) => e.copyWith(allpass: s.copyWith(f: v)),
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
                    (e) => e.copyWith(allpass: s.copyWith(frequency: v)),
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
                    (e) => e.copyWith(allpass: s.copyWith(m: v)),
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
                    (e) => e.copyWith(allpass: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'o',
                  value: s.o.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(o: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'order',
                  value: s.order.toDouble(),
                  min: 1.0,
                  max: 2.0,
                  defaultValue: 2.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(order: v.round())),
                  ),
                ),
                FilterParamDropdown<AllpassPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: AllpassPrecision.auto,
                  options: const [
                    AllpassPrecision.auto,
                    AllpassPrecision.s16,
                    AllpassPrecision.s32,
                    AllpassPrecision.f32,
                    AllpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<AllpassPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: AllpassPrecision.auto,
                  options: const [
                    AllpassPrecision.auto,
                    AllpassPrecision.s16,
                    AllpassPrecision.s32,
                    AllpassPrecision.f32,
                    AllpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<AllpassWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: AllpassWidthType.q,
                  options: const [
                    AllpassWidthType.h,
                    AllpassWidthType.q,
                    AllpassWidthType.o,
                    AllpassWidthType.s,
                    AllpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<AllpassTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: AllpassTransformType.di,
                  options: const [
                    AllpassTransformType.di,
                    AllpassTransformType.dii,
                    AllpassTransformType.tdi,
                    AllpassTransformType.tdii,
                    AllpassTransformType.latt,
                    AllpassTransformType.svf,
                    AllpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.707,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.707,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<AllpassWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: AllpassWidthType.q,
                  options: const [
                    AllpassWidthType.h,
                    AllpassWidthType.q,
                    AllpassWidthType.o,
                    AllpassWidthType.s,
                    AllpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(allpass: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AsubcutSettings>(
          stream: _watch((e) => e.asubcut),
          initialData: player.state.audioEffects.asubcut,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'asubcut',
              subtitle: 'lavfi-asubcut',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(asubcut: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'cutoff',
                  value: s.cutoff,
                  min: 2.0,
                  max: 200.0,
                  defaultValue: 20.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubcut: s.copyWith(cutoff: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level',
                  value: s.level,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubcut: s.copyWith(level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'order',
                  value: s.order.toDouble(),
                  min: 3.0,
                  max: 20.0,
                  defaultValue: 10.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asubcut: s.copyWith(order: v.round())),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AsupercutSettings>(
          stream: _watch((e) => e.asupercut),
          initialData: player.state.audioEffects.asupercut,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'asupercut',
              subtitle: 'lavfi-asupercut',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(asupercut: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'cutoff',
                  value: s.cutoff,
                  min: 20000.0,
                  max: 192000.0,
                  defaultValue: 20000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asupercut: s.copyWith(cutoff: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level',
                  value: s.level,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asupercut: s.copyWith(level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'order',
                  value: s.order.toDouble(),
                  min: 3.0,
                  max: 20.0,
                  defaultValue: 10.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asupercut: s.copyWith(order: v.round())),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AsuperpassSettings>(
          stream: _watch((e) => e.asuperpass),
          initialData: player.state.audioEffects.asuperpass,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'asuperpass',
              subtitle: 'lavfi-asuperpass',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(asuperpass: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'centerf',
                  value: s.centerf,
                  min: 2.0,
                  max: 999999.0,
                  defaultValue: 1000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperpass: s.copyWith(centerf: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level',
                  value: s.level,
                  min: 0.0,
                  max: 2.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperpass: s.copyWith(level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'order',
                  value: s.order.toDouble(),
                  min: 4.0,
                  max: 20.0,
                  defaultValue: 4.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperpass: s.copyWith(order: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'qfactor',
                  value: s.qfactor,
                  min: 0.01,
                  max: 100.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperpass: s.copyWith(qfactor: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AsuperstopSettings>(
          stream: _watch((e) => e.asuperstop),
          initialData: player.state.audioEffects.asuperstop,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'asuperstop',
              subtitle: 'lavfi-asuperstop',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(asuperstop: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'centerf',
                  value: s.centerf,
                  min: 2.0,
                  max: 999999.0,
                  defaultValue: 1000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperstop: s.copyWith(centerf: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level',
                  value: s.level,
                  min: 0.0,
                  max: 2.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperstop: s.copyWith(level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'order',
                  value: s.order.toDouble(),
                  min: 4.0,
                  max: 20.0,
                  defaultValue: 4.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperstop: s.copyWith(order: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'qfactor',
                  value: s.qfactor,
                  min: 0.01,
                  max: 100.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asuperstop: s.copyWith(qfactor: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<BandpassSettings>(
          stream: _watch((e) => e.bandpass),
          initialData: player.state.audioEffects.bandpass,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'bandpass',
              subtitle: 'lavfi-bandpass',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(bandpass: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<BandpassTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: BandpassTransformType.di,
                  options: const [
                    BandpassTransformType.di,
                    BandpassTransformType.dii,
                    BandpassTransformType.tdi,
                    BandpassTransformType.tdii,
                    BandpassTransformType.latt,
                    BandpassTransformType.svf,
                    BandpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(a: v)),
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
                    (e) => e.copyWith(bandpass: s.copyWith(b: v.round())),
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
                        e.copyWith(bandpass: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'csg',
                  value: s.csg,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(csg: v)),
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
                    (e) => e.copyWith(bandpass: s.copyWith(f: v)),
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
                    (e) => e.copyWith(bandpass: s.copyWith(frequency: v)),
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
                    (e) => e.copyWith(bandpass: s.copyWith(m: v)),
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
                    (e) => e.copyWith(bandpass: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamDropdown<BandpassPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: BandpassPrecision.auto,
                  options: const [
                    BandpassPrecision.auto,
                    BandpassPrecision.s16,
                    BandpassPrecision.s32,
                    BandpassPrecision.f32,
                    BandpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<BandpassPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: BandpassPrecision.auto,
                  options: const [
                    BandpassPrecision.auto,
                    BandpassPrecision.s16,
                    BandpassPrecision.s32,
                    BandpassPrecision.f32,
                    BandpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<BandpassWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: BandpassWidthType.q,
                  options: const [
                    BandpassWidthType.h,
                    BandpassWidthType.q,
                    BandpassWidthType.o,
                    BandpassWidthType.s,
                    BandpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<BandpassTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: BandpassTransformType.di,
                  options: const [
                    BandpassTransformType.di,
                    BandpassTransformType.dii,
                    BandpassTransformType.tdi,
                    BandpassTransformType.tdii,
                    BandpassTransformType.latt,
                    BandpassTransformType.svf,
                    BandpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(transform: v)),
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
                    (e) => e.copyWith(bandpass: s.copyWith(w: v)),
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
                    (e) => e.copyWith(bandpass: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<BandpassWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: BandpassWidthType.q,
                  options: const [
                    BandpassWidthType.h,
                    BandpassWidthType.q,
                    BandpassWidthType.o,
                    BandpassWidthType.s,
                    BandpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandpass: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<BandrejectSettings>(
          stream: _watch((e) => e.bandreject),
          initialData: player.state.audioEffects.bandreject,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'bandreject',
              subtitle: 'lavfi-bandreject',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(bandreject: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<BandrejectTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: BandrejectTransformType.di,
                  options: const [
                    BandrejectTransformType.di,
                    BandrejectTransformType.dii,
                    BandrejectTransformType.tdi,
                    BandrejectTransformType.tdii,
                    BandrejectTransformType.latt,
                    BandrejectTransformType.svf,
                    BandrejectTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(a: v)),
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
                    (e) => e.copyWith(bandreject: s.copyWith(b: v.round())),
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
                    (e) => e.copyWith(
                      bandreject: s.copyWith(blocksize: v.round()),
                    ),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(channels: v)),
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
                    (e) => e.copyWith(bandreject: s.copyWith(f: v)),
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
                    (e) => e.copyWith(bandreject: s.copyWith(frequency: v)),
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
                    (e) => e.copyWith(bandreject: s.copyWith(m: v)),
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
                    (e) => e.copyWith(bandreject: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(normalize: v)),
                  ),
                ),
                FilterParamDropdown<BandrejectPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: BandrejectPrecision.auto,
                  options: const [
                    BandrejectPrecision.auto,
                    BandrejectPrecision.s16,
                    BandrejectPrecision.s32,
                    BandrejectPrecision.f32,
                    BandrejectPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<BandrejectPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: BandrejectPrecision.auto,
                  options: const [
                    BandrejectPrecision.auto,
                    BandrejectPrecision.s16,
                    BandrejectPrecision.s32,
                    BandrejectPrecision.f32,
                    BandrejectPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<BandrejectWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: BandrejectWidthType.q,
                  options: const [
                    BandrejectWidthType.h,
                    BandrejectWidthType.q,
                    BandrejectWidthType.o,
                    BandrejectWidthType.s,
                    BandrejectWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<BandrejectTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: BandrejectTransformType.di,
                  options: const [
                    BandrejectTransformType.di,
                    BandrejectTransformType.dii,
                    BandrejectTransformType.tdi,
                    BandrejectTransformType.tdii,
                    BandrejectTransformType.latt,
                    BandrejectTransformType.svf,
                    BandrejectTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(transform: v)),
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
                    (e) => e.copyWith(bandreject: s.copyWith(w: v)),
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
                    (e) => e.copyWith(bandreject: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<BandrejectWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: BandrejectWidthType.q,
                  options: const [
                    BandrejectWidthType.h,
                    BandrejectWidthType.q,
                    BandrejectWidthType.o,
                    BandrejectWidthType.s,
                    BandrejectWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(bandreject: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<HighpassSettings>(
          stream: _watch((e) => e.highpass),
          initialData: player.state.audioEffects.highpass,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'highpass',
              subtitle: 'lavfi-highpass',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(highpass: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<HighpassTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: HighpassTransformType.di,
                  options: const [
                    HighpassTransformType.di,
                    HighpassTransformType.dii,
                    HighpassTransformType.tdi,
                    HighpassTransformType.tdii,
                    HighpassTransformType.latt,
                    HighpassTransformType.svf,
                    HighpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(a: v)),
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
                    (e) => e.copyWith(highpass: s.copyWith(b: v.round())),
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
                        e.copyWith(highpass: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(channels: v)),
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
                    (e) => e.copyWith(highpass: s.copyWith(f: v)),
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
                    (e) => e.copyWith(highpass: s.copyWith(frequency: v)),
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
                    (e) => e.copyWith(highpass: s.copyWith(m: v)),
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
                    (e) => e.copyWith(highpass: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(normalize: v)),
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
                    (e) => e.copyWith(highpass: s.copyWith(p: v.round())),
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
                    (e) => e.copyWith(highpass: s.copyWith(poles: v.round())),
                  ),
                ),
                FilterParamDropdown<HighpassPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: HighpassPrecision.auto,
                  options: const [
                    HighpassPrecision.auto,
                    HighpassPrecision.s16,
                    HighpassPrecision.s32,
                    HighpassPrecision.f32,
                    HighpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<HighpassPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: HighpassPrecision.auto,
                  options: const [
                    HighpassPrecision.auto,
                    HighpassPrecision.s16,
                    HighpassPrecision.s32,
                    HighpassPrecision.f32,
                    HighpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<HighpassWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: HighpassWidthType.q,
                  options: const [
                    HighpassWidthType.h,
                    HighpassWidthType.q,
                    HighpassWidthType.o,
                    HighpassWidthType.s,
                    HighpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<HighpassTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: HighpassTransformType.di,
                  options: const [
                    HighpassTransformType.di,
                    HighpassTransformType.dii,
                    HighpassTransformType.tdi,
                    HighpassTransformType.tdii,
                    HighpassTransformType.latt,
                    HighpassTransformType.svf,
                    HighpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.707,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.707,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<HighpassWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: HighpassWidthType.q,
                  options: const [
                    HighpassWidthType.h,
                    HighpassWidthType.q,
                    HighpassWidthType.o,
                    HighpassWidthType.s,
                    HighpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(highpass: s.copyWith(width_type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<LowpassSettings>(
          stream: _watch((e) => e.lowpass),
          initialData: player.state.audioEffects.lowpass,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'lowpass',
              subtitle: 'lavfi-lowpass',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(lowpass: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamDropdown<LowpassTransformType>(
                  label: 'a',
                  value: s.a,
                  defaultValue: LowpassTransformType.di,
                  options: const [
                    LowpassTransformType.di,
                    LowpassTransformType.dii,
                    LowpassTransformType.tdi,
                    LowpassTransformType.tdii,
                    LowpassTransformType.latt,
                    LowpassTransformType.svf,
                    LowpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(a: v)),
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
                    (e) => e.copyWith(lowpass: s.copyWith(b: v.round())),
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
                        e.copyWith(lowpass: s.copyWith(blocksize: v.round())),
                  ),
                ),
                FilterParamTextField(
                  label: 'c',
                  value: s.c,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 500.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'frequency',
                  value: s.frequency,
                  min: 0.0,
                  max: 999999.0,
                  defaultValue: 500.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(frequency: v)),
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
                    (e) => e.copyWith(lowpass: s.copyWith(m: v)),
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
                    (e) => e.copyWith(lowpass: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'normalize',
                  value: s.normalize,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(normalize: v)),
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
                    (e) => e.copyWith(lowpass: s.copyWith(p: v.round())),
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
                    (e) => e.copyWith(lowpass: s.copyWith(poles: v.round())),
                  ),
                ),
                FilterParamDropdown<LowpassPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: LowpassPrecision.auto,
                  options: const [
                    LowpassPrecision.auto,
                    LowpassPrecision.s16,
                    LowpassPrecision.s32,
                    LowpassPrecision.f32,
                    LowpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamDropdown<LowpassPrecision>(
                  label: 'r',
                  value: s.r,
                  defaultValue: LowpassPrecision.auto,
                  options: const [
                    LowpassPrecision.auto,
                    LowpassPrecision.s16,
                    LowpassPrecision.s32,
                    LowpassPrecision.f32,
                    LowpassPrecision.f64,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(r: v)),
                  ),
                ),
                FilterParamDropdown<LowpassWidthType>(
                  label: 't',
                  value: s.t,
                  defaultValue: LowpassWidthType.q,
                  options: const [
                    LowpassWidthType.h,
                    LowpassWidthType.q,
                    LowpassWidthType.o,
                    LowpassWidthType.s,
                    LowpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(t: v)),
                  ),
                ),
                FilterParamDropdown<LowpassTransformType>(
                  label: 'transform',
                  value: s.transform,
                  defaultValue: LowpassTransformType.di,
                  options: const [
                    LowpassTransformType.di,
                    LowpassTransformType.dii,
                    LowpassTransformType.tdi,
                    LowpassTransformType.tdii,
                    LowpassTransformType.latt,
                    LowpassTransformType.svf,
                    LowpassTransformType.zdf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(transform: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'w',
                  value: s.w,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.707,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(w: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'width',
                  value: s.width,
                  min: 0.0,
                  max: 99999.0,
                  defaultValue: 0.707,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(width: v)),
                  ),
                ),
                FilterParamDropdown<LowpassWidthType>(
                  label: 'width_type',
                  value: s.width_type,
                  defaultValue: LowpassWidthType.q,
                  options: const [
                    LowpassWidthType.h,
                    LowpassWidthType.q,
                    LowpassWidthType.o,
                    LowpassWidthType.s,
                    LowpassWidthType.k,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(lowpass: s.copyWith(width_type: v)),
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
