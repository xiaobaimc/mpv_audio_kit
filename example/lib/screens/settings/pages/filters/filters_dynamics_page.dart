// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.
//
// AUTO-GENERATED — do not edit by hand.

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../../shared/property_cards.dart';

/// Filters in the **Dynamics & loudness** category. Each card maps to a typed
/// `*Settings` field on the [AudioEffects] bundle.
class FiltersDynamicsPage extends StatefulWidget {
  final Player player;
  const FiltersDynamicsPage({super.key, required this.player});

  @override
  State<FiltersDynamicsPage> createState() => _FiltersDynamicsPageState();
}

class _FiltersDynamicsPageState extends State<FiltersDynamicsPage> {
  Player get player => widget.player;

  Stream<T> _watch<T>(T Function(AudioEffects) sel) =>
      player.stream.audioEffects.map(sel).distinct();

  String _f(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<AcompressorSettings>(
          stream: _watch((e) => e.acompressor),
          initialData: player.state.audioEffects.acompressor,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'acompressor',
              subtitle: 'lavfi-acompressor',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(acompressor: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'attack',
                  value: s.attack,
                  min: 0.01,
                  max: 2000.0,
                  defaultValue: 20.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(attack: v)),
                  ),
                ),
                FilterParamDropdown<AcompressorDetection>(
                  label: 'detection',
                  value: s.detection,
                  defaultValue: AcompressorDetection.rms,
                  options: const [
                    AcompressorDetection.peak,
                    AcompressorDetection.rms,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(detection: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'knee',
                  value: s.knee,
                  min: 1.0,
                  max: 8.0,
                  defaultValue: 2.82843,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(knee: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_in',
                  value: s.level_in,
                  min: 0.015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(level_in: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_sc',
                  value: s.level_sc,
                  min: 0.015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(level_sc: v)),
                  ),
                ),
                FilterParamDropdown<AcompressorLink>(
                  label: 'link',
                  value: s.link,
                  defaultValue: AcompressorLink.average,
                  options: const [
                    AcompressorLink.average,
                    AcompressorLink.maximum,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(link: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'makeup',
                  value: s.makeup,
                  min: 1.0,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(makeup: v)),
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
                    (e) => e.copyWith(acompressor: s.copyWith(mix: v)),
                  ),
                ),
                FilterParamDropdown<AcompressorMode>(
                  label: 'mode',
                  value: s.mode,
                  defaultValue: AcompressorMode.downward,
                  options: const [
                    AcompressorMode.downward,
                    AcompressorMode.upward,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(mode: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'ratio',
                  value: s.ratio,
                  min: 1.0,
                  max: 20.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(ratio: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'release',
                  value: s.release,
                  min: 0.01,
                  max: 9000.0,
                  defaultValue: 250.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(release: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'threshold',
                  value: s.threshold,
                  min: 0.000976563,
                  max: 1.0,
                  defaultValue: 0.125,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acompressor: s.copyWith(threshold: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AcontrastSettings>(
          stream: _watch((e) => e.acontrast),
          initialData: player.state.audioEffects.acontrast,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'acontrast',
              subtitle: 'lavfi-acontrast',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(acontrast: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'contrast',
                  value: s.contrast,
                  min: 0.0,
                  max: 100.0,
                  defaultValue: 33.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(acontrast: s.copyWith(contrast: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AdrcSettings>(
          stream: _watch((e) => e.adrc),
          initialData: player.state.audioEffects.adrc,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'adrc',
              subtitle: 'lavfi-adrc',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(adrc: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'attack',
                  value: s.attack,
                  min: 1.0,
                  max: 1000.0,
                  defaultValue: 50.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adrc: s.copyWith(attack: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adrc: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'release',
                  value: s.release,
                  min: 5.0,
                  max: 2000.0,
                  defaultValue: 100.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adrc: s.copyWith(release: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'transfer',
                  value: s.transfer,
                  defaultValue: '"p"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adrc: s.copyWith(transfer: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AdynamicequalizerSettings>(
          stream: _watch((e) => e.adynamicequalizer),
          initialData: player.state.audioEffects.adynamicequalizer,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'adynamicequalizer',
              subtitle: 'lavfi-adynamicequalizer',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(adynamicequalizer: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'attack',
                  value: s.attack,
                  min: 0.01,
                  max: 2000.0,
                  defaultValue: 20.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(attack: v)),
                  ),
                ),
                FilterParamDropdown<AdynamicequalizerAuto>(
                  label: 'auto',
                  value: s.auto,
                  defaultValue: AdynamicequalizerAuto.off,
                  options: const [
                    AdynamicequalizerAuto.disabled,
                    AdynamicequalizerAuto.off,
                    AdynamicequalizerAuto.on_,
                    AdynamicequalizerAuto.adaptive,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(auto: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'dfrequency',
                  value: s.dfrequency,
                  min: 2.0,
                  max: 1000000.0,
                  defaultValue: 1000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      adynamicequalizer: s.copyWith(dfrequency: v),
                    ),
                  ),
                ),
                FilterParamDropdown<AdynamicequalizerDftype>(
                  label: 'dftype',
                  value: s.dftype,
                  defaultValue: AdynamicequalizerDftype.bandpass,
                  options: const [
                    AdynamicequalizerDftype.bandpass,
                    AdynamicequalizerDftype.lowpass,
                    AdynamicequalizerDftype.highpass,
                    AdynamicequalizerDftype.peak,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(dftype: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'dqfactor',
                  value: s.dqfactor,
                  min: 0.001,
                  max: 1000.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(adynamicequalizer: s.copyWith(dqfactor: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'makeup',
                  value: s.makeup,
                  min: 0.0,
                  max: 1000.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(makeup: v)),
                  ),
                ),
                FilterParamDropdown<AdynamicequalizerMode>(
                  label: 'mode',
                  value: s.mode,
                  defaultValue: AdynamicequalizerMode.listen,
                  options: const [
                    AdynamicequalizerMode.listen,
                    AdynamicequalizerMode.cutbelow,
                    AdynamicequalizerMode.cutabove,
                    AdynamicequalizerMode.boostbelow,
                    AdynamicequalizerMode.boostabove,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(mode: v)),
                  ),
                ),
                FilterParamDropdown<AdynamicequalizerPrecision>(
                  label: 'precision',
                  value: s.precision,
                  defaultValue: AdynamicequalizerPrecision.auto,
                  options: const [
                    AdynamicequalizerPrecision.auto,
                    AdynamicequalizerPrecision.float,
                    AdynamicequalizerPrecision.double_,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(adynamicequalizer: s.copyWith(precision: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'range',
                  value: s.range,
                  min: 1.0,
                  max: 2000.0,
                  defaultValue: 50.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(range: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'ratio',
                  value: s.ratio,
                  min: 0.0,
                  max: 30.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(ratio: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'release',
                  value: s.release,
                  min: 0.01,
                  max: 2000.0,
                  defaultValue: 200.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(adynamicequalizer: s.copyWith(release: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'tfrequency',
                  value: s.tfrequency,
                  min: 2.0,
                  max: 1000000.0,
                  defaultValue: 1000.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      adynamicequalizer: s.copyWith(tfrequency: v),
                    ),
                  ),
                ),
                FilterParamDropdown<AdynamicequalizerTftype>(
                  label: 'tftype',
                  value: s.tftype,
                  defaultValue: AdynamicequalizerTftype.bell,
                  options: const [
                    AdynamicequalizerTftype.bell,
                    AdynamicequalizerTftype.lowshelf,
                    AdynamicequalizerTftype.highshelf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicequalizer: s.copyWith(tftype: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'threshold',
                  value: s.threshold,
                  min: 0.0,
                  max: 100.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(adynamicequalizer: s.copyWith(threshold: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'tqfactor',
                  value: s.tqfactor,
                  min: 0.001,
                  max: 1000.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(adynamicequalizer: s.copyWith(tqfactor: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AdynamicsmoothSettings>(
          stream: _watch((e) => e.adynamicsmooth),
          initialData: player.state.audioEffects.adynamicsmooth,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'adynamicsmooth',
              subtitle: 'lavfi-adynamicsmooth',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(adynamicsmooth: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'basefreq',
                  value: s.basefreq,
                  min: 2.0,
                  max: 1000000.0,
                  defaultValue: 22050.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(adynamicsmooth: s.copyWith(basefreq: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'sensitivity',
                  value: s.sensitivity,
                  min: 0.0,
                  max: 1000000.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(adynamicsmooth: s.copyWith(sensitivity: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AgateSettings>(
          stream: _watch((e) => e.agate),
          initialData: player.state.audioEffects.agate,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'agate',
              subtitle: 'lavfi-agate',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(agate: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'attack',
                  value: s.attack,
                  min: 0.01,
                  max: 9000.0,
                  defaultValue: 20.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(attack: v)),
                  ),
                ),
                FilterParamDropdown<AgateDetection>(
                  label: 'detection',
                  value: s.detection,
                  defaultValue: AgateDetection.rms,
                  options: const [AgateDetection.peak, AgateDetection.rms],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(detection: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'knee',
                  value: s.knee,
                  min: 1.0,
                  max: 8.0,
                  defaultValue: 2.828427125,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(knee: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_in',
                  value: s.level_in,
                  min: 0.015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(level_in: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_sc',
                  value: s.level_sc,
                  min: 0.015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(level_sc: v)),
                  ),
                ),
                FilterParamDropdown<AgateLink>(
                  label: 'link',
                  value: s.link,
                  defaultValue: AgateLink.average,
                  options: const [AgateLink.average, AgateLink.maximum],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(link: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'makeup',
                  value: s.makeup,
                  min: 1.0,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(makeup: v)),
                  ),
                ),
                FilterParamDropdown<AgateMode>(
                  label: 'mode',
                  value: s.mode,
                  defaultValue: AgateMode.downward,
                  options: const [AgateMode.downward, AgateMode.upward],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(mode: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'range',
                  value: s.range,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.06125,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(range: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'ratio',
                  value: s.ratio,
                  min: 1.0,
                  max: 9000.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(ratio: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'release',
                  value: s.release,
                  min: 0.01,
                  max: 9000.0,
                  defaultValue: 250.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(release: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'threshold',
                  value: s.threshold,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.125,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(agate: s.copyWith(threshold: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AlimiterSettings>(
          stream: _watch((e) => e.alimiter),
          initialData: player.state.audioEffects.alimiter,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'alimiter',
              subtitle: 'lavfi-alimiter',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(alimiter: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSwitch(
                  label: 'asc',
                  value: s.asc,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(asc: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'asc_level',
                  value: s.asc_level,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(asc_level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'attack',
                  value: s.attack,
                  min: 0.1,
                  max: 80.0,
                  defaultValue: 5.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(attack: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'latency',
                  value: s.latency,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(latency: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'level',
                  value: s.level,
                  defaultValue: true,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_in',
                  value: s.level_in,
                  min: .015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(level_in: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_out',
                  value: s.level_out,
                  min: .015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(level_out: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'limit',
                  value: s.limit,
                  min: 0.0625,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(limit: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'release',
                  value: s.release,
                  min: 1.0,
                  max: 8000.0,
                  defaultValue: 50.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(alimiter: s.copyWith(release: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<ApsyclipSettings>(
          stream: _watch((e) => e.apsyclip),
          initialData: player.state.audioEffects.apsyclip,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'apsyclip',
              subtitle: 'lavfi-apsyclip',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(apsyclip: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'adaptive',
                  value: s.adaptive,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apsyclip: s.copyWith(adaptive: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'clip',
                  value: s.clip,
                  min: .015625,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apsyclip: s.copyWith(clip: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'diff',
                  value: s.diff,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apsyclip: s.copyWith(diff: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'iterations',
                  value: s.iterations.toDouble(),
                  min: 1.0,
                  max: 20.0,
                  defaultValue: 10.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(apsyclip: s.copyWith(iterations: v.round())),
                  ),
                ),
                FilterParamSwitch(
                  label: 'level',
                  value: s.level,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apsyclip: s.copyWith(level: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_in',
                  value: s.level_in,
                  min: .015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apsyclip: s.copyWith(level_in: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'level_out',
                  value: s.level_out,
                  min: .015625,
                  max: 64.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(apsyclip: s.copyWith(level_out: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<AsoftclipSettings>(
          stream: _watch((e) => e.asoftclip),
          initialData: player.state.audioEffects.asoftclip,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'asoftclip',
              subtitle: 'lavfi-asoftclip',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(asoftclip: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'output',
                  value: s.output,
                  min: 0.000001,
                  max: 16.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asoftclip: s.copyWith(output: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'oversample',
                  value: s.oversample.toDouble(),
                  min: 1.0,
                  max: 64.0,
                  defaultValue: 1.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      asoftclip: s.copyWith(oversample: v.round()),
                    ),
                  ),
                ),
                FilterParamSlider(
                  label: 'param',
                  value: s.param,
                  min: 0.01,
                  max: 3.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asoftclip: s.copyWith(param: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'threshold',
                  value: s.threshold,
                  min: 0.000001,
                  max: 1.0,
                  defaultValue: 1.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asoftclip: s.copyWith(threshold: v)),
                  ),
                ),
                FilterParamDropdown<AsoftclipTypes>(
                  label: 'type',
                  value: s.type,
                  defaultValue: AsoftclipTypes.hard,
                  options: const [
                    AsoftclipTypes.hard,
                    AsoftclipTypes.tanh,
                    AsoftclipTypes.atan,
                    AsoftclipTypes.cubic,
                    AsoftclipTypes.exp,
                    AsoftclipTypes.alg,
                    AsoftclipTypes.quintic,
                    AsoftclipTypes.sin,
                    AsoftclipTypes.erf,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(asoftclip: s.copyWith(type: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<CompandSettings>(
          stream: _watch((e) => e.compand),
          initialData: player.state.audioEffects.compand,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'compand',
              subtitle: 'lavfi-compand',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(compand: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamTextField(
                  label: 'attacks',
                  value: s.attacks,
                  defaultValue: '"0"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(compand: s.copyWith(attacks: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'decays',
                  value: s.decays,
                  defaultValue: '"0.8"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(compand: s.copyWith(decays: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'delay',
                  value: s.delay,
                  min: 0.0,
                  max: 20.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(compand: s.copyWith(delay: v)),
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
                    (e) => e.copyWith(compand: s.copyWith(gain: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'points',
                  value: s.points,
                  defaultValue: '"-70/-70|-60/-20|1/0"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(compand: s.copyWith(points: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'volume',
                  value: s.volume,
                  min: -900.0,
                  max: 0.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(compand: s.copyWith(volume: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<DeesserSettings>(
          stream: _watch((e) => e.deesser),
          initialData: player.state.audioEffects.deesser,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'deesser',
              subtitle: 'lavfi-deesser',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(deesser: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(deesser: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'i',
                  value: s.i,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(deesser: s.copyWith(i: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.5,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(deesser: s.copyWith(m: v)),
                  ),
                ),
                FilterParamDropdown<DeesserMode>(
                  label: 's',
                  value: s.s,
                  defaultValue: DeesserMode.o,
                  options: const [DeesserMode.i, DeesserMode.o, DeesserMode.e],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(deesser: s.copyWith(s: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<DrmeterSettings>(
          stream: _watch((e) => e.drmeter),
          initialData: player.state.audioEffects.drmeter,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'drmeter',
              subtitle: 'lavfi-drmeter',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(drmeter: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'length',
                  value: s.length,
                  min: .01,
                  max: 10.0,
                  defaultValue: 3.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(drmeter: s.copyWith(length: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<DynaudnormSettings>(
          stream: _watch((e) => e.dynaudnorm),
          initialData: player.state.audioEffects.dynaudnorm,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'dynaudnorm',
              subtitle: 'lavfi-dynaudnorm',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(dynaudnorm: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSwitch(
                  label: 'altboundary',
                  value: s.altboundary,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(altboundary: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'b',
                  value: s.b,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(b: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'c',
                  value: s.c,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'compress',
                  value: s.compress,
                  min: 0.0,
                  max: 30.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(compress: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'correctdc',
                  value: s.correctdc,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(correctdc: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'coupling',
                  value: s.coupling,
                  defaultValue: true,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(coupling: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'curve',
                  value: s.curve,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(curve: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f.toDouble(),
                  min: 10.0,
                  max: 8000.0,
                  defaultValue: 500.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(f: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'framelen',
                  value: s.framelen.toDouble(),
                  min: 10.0,
                  max: 8000.0,
                  defaultValue: 500.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) =>
                        e.copyWith(dynaudnorm: s.copyWith(framelen: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'g',
                  value: s.g.toDouble(),
                  min: 3.0,
                  max: 301.0,
                  defaultValue: 31.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(g: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'gausssize',
                  value: s.gausssize.toDouble(),
                  min: 3.0,
                  max: 301.0,
                  defaultValue: 31.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(
                      dynaudnorm: s.copyWith(gausssize: v.round()),
                    ),
                  ),
                ),
                FilterParamTextField(
                  label: 'h',
                  value: s.h,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(h: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 1.0,
                  max: 100.0,
                  defaultValue: 10.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(m: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'maxgain',
                  value: s.maxgain,
                  min: 1.0,
                  max: 100.0,
                  defaultValue: 10.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(maxgain: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'n',
                  value: s.n,
                  defaultValue: true,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(n: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'o',
                  value: s.o,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: .0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(o: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'overlap',
                  value: s.overlap,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: .0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(overlap: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'p',
                  value: s.p,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.95,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(p: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'peak',
                  value: s.peak,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.95,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(peak: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'r',
                  value: s.r,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(r: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 's',
                  value: s.s,
                  min: 0.0,
                  max: 30.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(s: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 't',
                  value: s.t,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(t: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'targetrms',
                  value: s.targetrms,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(targetrms: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'threshold',
                  value: s.threshold,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(threshold: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'v',
                  value: s.v,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(dynaudnorm: s.copyWith(v: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<Ebur128Settings>(
          stream: _watch((e) => e.ebur128),
          initialData: player.state.audioEffects.ebur128,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'ebur128',
              subtitle: 'lavfi-ebur128',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(ebur128: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSwitch(
                  label: 'dualmono',
                  value: s.dualmono,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(dualmono: v)),
                  ),
                ),
                FilterParamDropdown<Ebur128Gaugetype>(
                  label: 'gauge',
                  value: s.gauge,
                  defaultValue: Ebur128Gaugetype.momentary,
                  options: const [
                    Ebur128Gaugetype.momentary,
                    Ebur128Gaugetype.m,
                    Ebur128Gaugetype.shortterm,
                    Ebur128Gaugetype.s,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(gauge: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'metadata',
                  value: s.metadata,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(metadata: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'meter',
                  value: s.meter.toDouble(),
                  min: 9.0,
                  max: 18.0,
                  defaultValue: 9.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(meter: v.round())),
                  ),
                ),
                FilterParamSlider(
                  label: 'panlaw',
                  value: s.panlaw,
                  min: -10.0,
                  max: 0.0,
                  defaultValue: -3.01029995663978,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(panlaw: v)),
                  ),
                ),
                FilterParamDropdown<Ebur128Scaletype>(
                  label: 'scale',
                  value: s.scale,
                  defaultValue: Ebur128Scaletype.absolute,
                  options: const [
                    Ebur128Scaletype.absolute,
                    Ebur128Scaletype.LUFS,
                    Ebur128Scaletype.relative,
                    Ebur128Scaletype.LU,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(scale: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'size',
                  value: s.size,
                  defaultValue: '"640x480"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(size: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'target',
                  value: s.target.toDouble(),
                  min: -23.0,
                  max: 0.0,
                  defaultValue: -23.toDouble(),
                  labelBuilder: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(target: v.round())),
                  ),
                ),
                FilterParamSwitch(
                  label: 'video',
                  value: s.video,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(ebur128: s.copyWith(video: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<LoudnormSettings>(
          stream: _watch((e) => e.loudnorm),
          initialData: player.state.audioEffects.loudnorm,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'loudnorm',
              subtitle: 'lavfi-loudnorm',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(loudnorm: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'I',
                  value: s.I,
                  min: -70.0,
                  max: -5.0,
                  defaultValue: -24.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(I: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'LRA',
                  value: s.LRA,
                  min: 1.0,
                  max: 50.0,
                  defaultValue: 7.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(LRA: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'TP',
                  value: s.TP,
                  min: -9.0,
                  max: 0.0,
                  defaultValue: -2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(TP: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'dual_mono',
                  value: s.dual_mono,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(dual_mono: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'i',
                  value: s.i,
                  min: -70.0,
                  max: -5.0,
                  defaultValue: -24.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(i: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'linear',
                  value: s.linear,
                  defaultValue: true,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(linear: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'lra',
                  value: s.lra,
                  min: 1.0,
                  max: 50.0,
                  defaultValue: 7.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(lra: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'measured_I',
                  value: s.measured_I,
                  min: -99.0,
                  max: 0.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(measured_I: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'measured_LRA',
                  value: s.measured_LRA,
                  min: 0.0,
                  max: 99.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(measured_LRA: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'measured_TP',
                  value: s.measured_TP,
                  min: -99.0,
                  max: 99.0,
                  defaultValue: 99.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(measured_TP: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'measured_i',
                  value: s.measured_i,
                  min: -99.0,
                  max: 0.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(measured_i: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'measured_lra',
                  value: s.measured_lra,
                  min: 0.0,
                  max: 99.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(measured_lra: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'measured_thresh',
                  value: s.measured_thresh,
                  min: -99.0,
                  max: 0.0,
                  defaultValue: -70.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(measured_thresh: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'measured_tp',
                  value: s.measured_tp,
                  min: -99.0,
                  max: 99.0,
                  defaultValue: 99.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(measured_tp: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'offset',
                  value: s.offset,
                  min: -99.0,
                  max: 99.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(offset: v)),
                  ),
                ),
                FilterParamDropdown<LoudnormPrintFormat>(
                  label: 'print_format',
                  value: s.print_format,
                  defaultValue: LoudnormPrintFormat.none,
                  options: const [
                    LoudnormPrintFormat.none,
                    LoudnormPrintFormat.json,
                    LoudnormPrintFormat.summary,
                  ],
                  optionLabel: (o) => o.mpvValue,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(print_format: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'stats_file',
                  value: s.stats_file,
                  defaultValue: '""',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(stats_file: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'tp',
                  value: s.tp,
                  min: -9.0,
                  max: 0.0,
                  defaultValue: -2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(loudnorm: s.copyWith(tp: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<McompandSettings>(
          stream: _watch((e) => e.mcompand),
          initialData: player.state.audioEffects.mcompand,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'mcompand',
              subtitle: 'lavfi-mcompand',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(mcompand: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamTextField(
                  label: 'args',
                  value: s.args,
                  defaultValue:
                      '"0.005,0.1 6 -47/-40,-34/-34,-17/-33 100 | 0.003,0.05 6 -47/-40,-34/-34,-17/-33 400 | 0.000625,0.0125 6 -47/-40,-34/-34,-15/-33 1600 | 0.0001,0.025 6 -47/-40,-34/-34,-31/-31,-0/-30 6400 | 0,0.025 6 -38/-31,-28/-28,-0/-25 22000"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(mcompand: s.copyWith(args: v)),
                  ),
                ),
              ],
            );
          },
        ),
        StreamBuilder<SpeechnormSettings>(
          stream: _watch((e) => e.speechnorm),
          initialData: player.state.audioEffects.speechnorm,
          builder: (context, snap) {
            final s = snap.data!;
            return ExpandableFilterCard(
              title: 'speechnorm',
              subtitle: 'lavfi-speechnorm',
              icon: Icons.tune,
              enabled: s.enabled,
              onToggle: (v) => player.updateAudioEffects(
                (e) => e.copyWith(speechnorm: s.copyWith(enabled: v)),
              ),
              params: [
                FilterParamSlider(
                  label: 'c',
                  value: s.c,
                  min: 1.0,
                  max: 50.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(c: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'channels',
                  value: s.channels,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(channels: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'compression',
                  value: s.compression,
                  min: 1.0,
                  max: 50.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(compression: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'e',
                  value: s.e,
                  min: 1.0,
                  max: 50.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(e: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'expansion',
                  value: s.expansion,
                  min: 1.0,
                  max: 50.0,
                  defaultValue: 2.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(expansion: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'f',
                  value: s.f,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.001,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(f: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'fall',
                  value: s.fall,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.001,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(fall: v)),
                  ),
                ),
                FilterParamTextField(
                  label: 'h',
                  value: s.h,
                  defaultValue: '"all"',
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(h: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'i',
                  value: s.i,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(i: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'invert',
                  value: s.invert,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(invert: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'l',
                  value: s.l,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(l: v)),
                  ),
                ),
                FilterParamSwitch(
                  label: 'link',
                  value: s.link,
                  defaultValue: false,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(link: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'm',
                  value: s.m,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(m: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'p',
                  value: s.p,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.95,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(p: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'peak',
                  value: s.peak,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.95,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(peak: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'r',
                  value: s.r,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.001,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(r: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'raise',
                  value: s.raise,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.001,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(raise: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'rms',
                  value: s.rms,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(rms: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 't',
                  value: s.t,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(t: v)),
                  ),
                ),
                FilterParamSlider(
                  label: 'threshold',
                  value: s.threshold,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.0,
                  labelBuilder: _f,
                  onChanged: (v) => player.updateAudioEffects(
                    (e) => e.copyWith(speechnorm: s.copyWith(threshold: v)),
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
