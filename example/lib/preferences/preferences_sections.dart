import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_dropdown.dart';
import '../atoms/atom_label.dart';
import '../atoms/atom_number_input.dart';
import '../atoms/atom_text_input.dart';
import '../atoms/atom_toggle.dart';
import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';
import 'prefs_bus.dart';

// ──────────────────────────────────────────────────────────────────────
// Standardised control widths so every row's left edge of the control
// column lines up. Variation only by ROLE: wide vs. standard.
// ──────────────────────────────────────────────────────────────────────
const double _wLabel       = 180;
const double _wDropdown    = 200;
const double _wDropdownXL  = 280;   // `audio-device` (long descriptions)
const double _wNumber      = 100;
const double _wText        = 280;

// ──────────────────────────────────────────────────────────────────────
// Curated dropdown option lists.
// ──────────────────────────────────────────────────────────────────────

const _sampleRates = <int>[
  8000, 11025, 16000, 22050, 32000, 44100, 48000,
  88200, 96000, 176400, 192000,
];

const _commonChannels = <Channels>[
  Channels.auto,
  Channels.autoSafe,
  Channels.mono,
  Channels.stereo,
  Channels.fiveOne,
];

const _fftSizes = <int>[256, 512, 1024, 2048, 4096];

const _drivers = <String>[
  'auto', 'coreaudio', 'avfoundation', 'audiounit',
  'wasapi', 'alsa', 'pulse', 'pipewire', 'jack', 'oss',
  'audiotrack', 'aaudio', 'opensles', 'sdl', 'null',
];

final _spdifOptions = <Spdif?>[null, ...Spdif.values];

// ──────────────────────────────────────────────────────────────────────
// Sections
// ──────────────────────────────────────────────────────────────────────

class AudioOutputSection extends StatelessWidget {
  const AudioOutputSection({super.key});
  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubHeader('routing'),
        _PrefRow(
          label: 'audio-device',
          description: 'OS device used for playback',
          control: StreamBuilder<List<Device>>(
            stream: p.stream.audioDevices,
            builder: (ctx, listSnap) => StreamBuilder<Device>(
              stream: p.stream.audioDevice,
              builder: (ctx, curSnap) {
                final list = listSnap.data ?? const <Device>[];
                final cur = curSnap.data;
                if (list.isEmpty || cur == null) return const _Pending();
                final options = list.contains(cur) ? list : [cur, ...list];
                return AtomDropdown<Device>(
                  value: cur,
                  options: options,
                  onChanged: (v) => PrefsScope.of(ctx).apply(
                    currentValue: cur,
                    newValue: v,
                    setter: p.setAudioDevice,
                  ),
                  format: (d) => d.description.isEmpty ? d.name : d.description,
                  width: _wDropdownXL,
                );
              },
            ),
          ),
        ),
        _PrefRow(
          label: 'ao',
          description: 'audio output backend; auto picks the platform default',
          control: StreamBuilder<String>(
            stream: p.stream.audioDriver,
            builder: (ctx, snap) {
              final cur = snap.data ?? 'auto';
              final opts = _drivers.contains(cur) ? _drivers : [cur, ..._drivers];
              return AtomDropdown<String>(
                value: cur,
                options: opts,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setAudioDriver,
                ),
                format: (d) => d,
                width: _wDropdown,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'audio-exclusive',
          description: 'bypass the OS mixer for direct device access',
          control: StreamBuilder<bool>(
            stream: p.stream.audioExclusive,
            builder: (ctx, snap) {
              final cur = snap.data ?? false;
              return AtomToggle(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setAudioExclusive,
                ),
              );
            },
          ),
        ),
        _PrefRow(
          label: 'audio-spdif',
          description: 'send a compressed bitstream straight to the receiver',
          control: StreamBuilder<Set<Spdif>>(
            stream: p.stream.audioSpdif,
            builder: (ctx, snap) {
              final s = snap.data ?? const <Spdif>{};
              final cur = s.isEmpty ? null : s.first;
              return AtomDropdown<Spdif?>(
                value: cur,
                options: _spdifOptions,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: v == null ? const <Spdif>{} : {v},
                  setter: p.setAudioSpdif,
                ),
                format: (v) => v == null ? 'off' : v.name,
                width: _wDropdown,
              );
            },
          ),
        ),
        const _SubHeader('format'),
        _PrefRow(
          label: 'audio-format',
          description: 'sample format requested from the AO',
          control: StreamBuilder<Format>(
            stream: p.stream.audioFormat,
            builder: (ctx, snap) {
              final cur = snap.data ?? Format.values.first;
              return AtomDropdown<Format>(
                value: cur,
                options: Format.values,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setAudioFormat,
                ),
                format: (f) => f.name,
                width: _wDropdown,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'audio-samplerate',
          description: 'sample rate requested from the AO',
          control: StreamBuilder<int>(
            stream: p.stream.audioSampleRate,
            builder: (ctx, snap) {
              final cur = snap.data ?? 0;
              final options = _sampleRates.contains(cur)
                  ? _sampleRates
                  : [cur, ..._sampleRates];
              return AtomDropdown<int>(
                value: cur,
                options: options,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setAudioSampleRate,
                ),
                format: (r) => r == 0 ? 'auto' : '$r Hz',
                width: _wDropdown,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'audio-channels',
          description: 'channel layout requested from the AO',
          control: StreamBuilder<Channels>(
            stream: p.stream.audioChannels,
            builder: (ctx, snap) {
              final cur = snap.data ?? Channels.auto;
              final options = _commonChannels.contains(cur)
                  ? _commonChannels
                  : [cur, ..._commonChannels];
              return AtomDropdown<Channels>(
                value: cur,
                options: options,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setAudioChannels,
                ),
                format: (c) => c.mpvValue,
                width: _wDropdown,
              );
            },
          ),
        ),
        const _SubHeader('level'),
        _PrefRow(
          label: 'mute',
          description: 'silence the output without changing volume',
          control: StreamBuilder<bool>(
            stream: p.stream.mute,
            builder: (ctx, snap) {
              final cur = snap.data ?? false;
              return AtomToggle(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setMute,
                ),
              );
            },
          ),
        ),
        _PrefRow(
          label: 'volume-gain',
          description: 'extra gain in dB applied after the volume slider',
          control: StreamBuilder<double>(
            stream: p.stream.volumeGain,
            builder: (ctx, snap) {
              final cur = snap.data ?? 0.0;
              return AtomNumberInput(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setVolumeGain,
                ),
                decimals: 1,
                min: -30,
                max: 30,
                width: _wNumber,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'audio-delay',
          description: 'shift audio relative to the playhead, in milliseconds',
          control: StreamBuilder<Duration>(
            stream: p.stream.audioDelay,
            builder: (ctx, snap) {
              final cur = snap.data ?? Duration.zero;
              return AtomNumberInput(
                value: cur.inMilliseconds.toDouble(),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: Duration(milliseconds: v.round()),
                  setter: p.setAudioDelay,
                ),
                decimals: 0,
                min: -10000,
                max: 10000,
                width: _wNumber,
              );
            },
          ),
        ),
      ],
    );
  }
}

class DecoderSection extends StatelessWidget {
  const DecoderSection({super.key});
  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrefRow(
          label: 'speed',
          description: 'playback speed multiplier (1.0 = normal)',
          control: StreamBuilder<double>(
            stream: p.stream.rate,
            builder: (ctx, snap) {
              final cur = snap.data ?? 1.0;
              return AtomNumberInput(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setRate,
                ),
                decimals: 2,
                min: 0.25,
                max: 4.0,
                width: _wNumber,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'pitch',
          description: 'pitch multiplier (1.0 = normal); independent from speed',
          control: StreamBuilder<double>(
            stream: p.stream.pitch,
            builder: (ctx, snap) {
              final cur = snap.data ?? 1.0;
              return AtomNumberInput(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setPitch,
                ),
                decimals: 3,
                min: 0.5,
                max: 2.0,
                width: _wNumber,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'audio-pitch-correction',
          description: 'preserve pitch when speed changes (rubberband)',
          control: StreamBuilder<bool>(
            stream: p.stream.pitchCorrection,
            builder: (ctx, snap) {
              final cur = snap.data ?? false;
              return AtomToggle(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setPitchCorrection,
                ),
              );
            },
          ),
        ),
        _PrefRow(
          label: 'volume-max',
          description: 'upper bound for the volume slider, in percent',
          control: StreamBuilder<double>(
            stream: p.stream.volumeMax,
            builder: (ctx, snap) {
              final cur = snap.data ?? 130;
              return AtomNumberInput(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setVolumeMax,
                ),
                decimals: 0,
                min: 100,
                max: 1000,
                width: _wNumber,
              );
            },
          ),
        ),
      ],
    );
  }
}

class ReplayGainSection extends StatelessWidget {
  const ReplayGainSection({super.key});
  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<ReplayGainSettings>(
      stream: p.stream.replayGain,
      initialData: p.state.replayGain,
      builder: (ctx, snap) {
        final s = snap.data ?? const ReplayGainSettings();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrefRow(
              label: 'replaygain',
              description: 'which gain tag to apply: track, album or off',
              control: AtomDropdown<ReplayGain>(
                value: s.mode,
                options: ReplayGain.values,
                onChanged: (m) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(mode: m),
                  setter: p.setReplayGain,
                ),
                format: (m) => m.name,
                width: _wDropdown,
              ),
            ),
            _PrefRow(
              label: 'replaygain-preamp',
              description: 'extra dB applied on top of the replay-gain value',
              control: AtomNumberInput(
                value: s.preamp,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(preamp: v),
                  setter: p.setReplayGain,
                ),
                decimals: 1,
                min: -15,
                max: 15,
                width: _wNumber,
              ),
            ),
            _PrefRow(
              label: 'replaygain-clip',
              description: 'lower preamp automatically to prevent clipping',
              control: AtomToggle(
                value: s.clip,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(clip: v),
                  setter: p.setReplayGain,
                ),
              ),
            ),
            _PrefRow(
              label: 'replaygain-fallback',
              description: 'gain to apply when the file has no replay-gain tag',
              control: AtomNumberInput(
                value: s.fallback,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(fallback: v),
                  setter: p.setReplayGain,
                ),
                decimals: 1,
                min: -15,
                max: 15,
                width: _wNumber,
              ),
            ),
          ],
        );
      },
    );
  }
}

class NetworkSection extends StatelessWidget {
  const NetworkSection({super.key});
  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrefRow(
          label: 'network-timeout',
          description: 'maximum time to wait on a network read, in seconds',
          control: StreamBuilder<Duration>(
            stream: p.stream.networkTimeout,
            builder: (ctx, snap) {
              final cur = snap.data ?? const Duration(seconds: 60);
              return AtomNumberInput(
                value: cur.inSeconds.toDouble(),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: Duration(seconds: v.round()),
                  setter: p.setNetworkTimeout,
                ),
                decimals: 0,
                min: 1,
                max: 600,
                width: _wNumber,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'tls-verify',
          description: 'verify the HTTPS peer certificate chain',
          control: StreamBuilder<bool>(
            stream: p.stream.tlsVerify,
            builder: (ctx, snap) {
              final cur = snap.data ?? true;
              return AtomToggle(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setTlsVerify,
                ),
              );
            },
          ),
        ),
        const _PrefRow(
          label: 'tls-ca-file',
          description: 'PEM CA bundle path; empty restores the bundled default',
          control: _TlsCaFileInput(),
        ),
      ],
    );
  }
}

/// Stateful only because it owns a [TextEditingController]. Empty
/// commit restores the bundled CA per [Player.setTlsCaFile] doc.
class _TlsCaFileInput extends StatefulWidget {
  const _TlsCaFileInput();
  @override
  State<_TlsCaFileInput> createState() => _TlsCaFileInputState();
}

class _TlsCaFileInputState extends State<_TlsCaFileInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return AtomTextInput(
      controller: _controller,
      onSubmitted: (v) => p.setTlsCaFile(v.trim()),
      width: _wText,
    );
  }
}

class CacheSection extends StatelessWidget {
  const CacheSection({super.key});
  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubHeader('cache'),
        StreamBuilder<CacheSettings>(
          stream: p.stream.cache,
          initialData: p.state.cache,
          builder: (ctx, snap) {
            final c = snap.data ?? const CacheSettings();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrefRow(
                  label: 'cache',
                  description: 'demuxer cache strategy: auto, yes or no',
                  control: AtomDropdown<Cache>(
                    value: c.mode,
                    options: Cache.values,
                    onChanged: (m) => PrefsScope.of(ctx).apply(
                      currentValue: c,
                      newValue: c.copyWith(mode: m),
                      setter: p.setCache,
                    ),
                    format: (m) => m.name,
                    width: _wDropdown,
                  ),
                ),
                _PrefRow(
                  label: 'cache-secs',
                  description: 'maximum seconds of audio kept in the demuxer cache',
                  control: AtomNumberInput(
                    value: c.secs.inSeconds.toDouble(),
                    onChanged: (v) => PrefsScope.of(ctx).apply(
                      currentValue: c,
                      newValue: c.copyWith(
                          secs: Duration(seconds: v.round())),
                      setter: p.setCache,
                    ),
                    decimals: 0,
                    min: 0,
                    max: 600,
                    width: _wNumber,
                  ),
                ),
                _PrefRow(
                  label: 'cache-on-disk',
                  description: 'spill the cache to disk when memory fills',
                  control: AtomToggle(
                    value: c.onDisk,
                    onChanged: (v) => PrefsScope.of(ctx).apply(
                      currentValue: c,
                      newValue: c.copyWith(onDisk: v),
                      setter: p.setCache,
                    ),
                  ),
                ),
                _PrefRow(
                  label: 'cache-pause',
                  description: 'pause playback if the cache empties on a slow network',
                  control: AtomToggle(
                    value: c.pause,
                    onChanged: (v) => PrefsScope.of(ctx).apply(
                      currentValue: c,
                      newValue: c.copyWith(pause: v),
                      setter: p.setCache,
                    ),
                  ),
                ),
                _PrefRow(
                  label: 'cache-pause-wait',
                  description: 'seconds of cache to refill before resuming',
                  control: AtomNumberInput(
                    value: c.pauseWait.inMilliseconds / 1000.0,
                    onChanged: (v) => PrefsScope.of(ctx).apply(
                      currentValue: c,
                      newValue: c.copyWith(
                          pauseWait:
                              Duration(milliseconds: (v * 1000).round())),
                      setter: p.setCache,
                    ),
                    decimals: 1,
                    min: 0,
                    max: 60,
                    width: _wNumber,
                  ),
                ),
              ],
            );
          },
        ),
        const _SubHeader('buffer'),
        _PrefRow(
          label: 'audio-buffer',
          description: 'AO ring buffer size in milliseconds; trade latency for underrun headroom',
          control: StreamBuilder<Duration>(
            stream: p.stream.audioBuffer,
            builder: (ctx, snap) {
              final cur = snap.data ?? const Duration(milliseconds: 200);
              return AtomNumberInput(
                value: cur.inMilliseconds.toDouble(),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: Duration(milliseconds: v.round()),
                  setter: p.setAudioBuffer,
                ),
                decimals: 0,
                min: 0,
                max: 5000,
                width: _wNumber,
              );
            },
          ),
        ),
        const _SubHeader('demuxer'),
        _PrefRow(
          label: 'demuxer-max-bytes',
          description: 'soft cap on the forward demuxer cache, in megabytes',
          control: StreamBuilder<int>(
            stream: p.stream.demuxerMaxBytes,
            builder: (ctx, snap) {
              final cur = snap.data ?? 0;
              return AtomNumberInput(
                value: cur / (1024 * 1024),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: (v * 1024 * 1024).round(),
                  setter: p.setDemuxerMaxBytes,
                ),
                decimals: 0,
                min: 1,
                max: 4096,
                width: _wNumber,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'demuxer-max-back-bytes',
          description: 'memory kept behind the playhead for fast seeks back, in megabytes',
          control: StreamBuilder<int>(
            stream: p.stream.demuxerMaxBackBytes,
            builder: (ctx, snap) {
              final cur = snap.data ?? 0;
              return AtomNumberInput(
                value: cur / (1024 * 1024),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: (v * 1024 * 1024).round(),
                  setter: p.setDemuxerMaxBackBytes,
                ),
                decimals: 0,
                min: 0,
                max: 4096,
                width: _wNumber,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'demuxer-readahead-secs',
          description: 'minimum seconds the demuxer reads ahead of the playhead',
          control: StreamBuilder<int>(
            stream: p.stream.demuxerReadaheadSecs,
            builder: (ctx, snap) {
              final cur = snap.data ?? 20;
              return AtomNumberInput(
                value: cur.toDouble(),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v.round(),
                  setter: p.setDemuxerReadaheadSecs,
                ),
                decimals: 0,
                min: 0,
                max: 600,
                width: _wNumber,
              );
            },
          ),
        ),
      ],
    );
  }
}

class VisualizerSection extends StatelessWidget {
  const VisualizerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<SpectrumSettings>(
      stream: p.stream.spectrum,
      initialData: p.spectrumSettings,
      builder: (ctx, snap) {
        final s = snap.data ?? p.spectrumSettings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SubHeader('bands'),
            _PrefRow(
              label: 'fft-size',
              description: 'size of the FFT used to compute the bands; powers of two',
              control: AtomDropdown<int>(
                value: s.fftSize,
                options: _fftSizes,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(fftSize: v),
                  setter: p.setSpectrum,
                ),
                format: (n) => '$n',
                width: _wDropdown,
              ),
            ),
            _PrefRow(
              label: 'band-count',
              description: 'how many perceptual bands the FFT bins are aggregated into',
              control: AtomNumberInput(
                value: s.bandCount.toDouble(),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(bandCount: v.round()),
                  setter: p.setSpectrum,
                ),
                decimals: 0,
                min: 8,
                max: 256,
                width: _wNumber,
              ),
            ),
            _PrefRow(
              label: 'band-low-hz',
              description: 'lowest frequency mapped to the first band',
              control: AtomNumberInput(
                value: s.bandLowHz,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(
                      bandLowHz: v.clamp(10, s.bandHighHz - 1)),
                  setter: p.setSpectrum,
                ),
                decimals: 0,
                min: 10,
                max: 1000,
                width: _wNumber,
              ),
            ),
            _PrefRow(
              label: 'band-high-hz',
              description: 'highest frequency mapped to the last band',
              control: AtomNumberInput(
                value: s.bandHighHz,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(
                      bandHighHz: v.clamp(s.bandLowHz + 1, 22050)),
                  setter: p.setSpectrum,
                ),
                decimals: 0,
                min: 1000,
                max: 22050,
                width: _wNumber,
              ),
            ),
            _PrefRow(
              label: 'window',
              description: 'FFT window function; controls spectral leakage',
              control: AtomDropdown<WindowFunction>(
                value: s.window,
                options: WindowFunction.values,
                onChanged: (w) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(window: w),
                  setter: p.setSpectrum,
                ),
                format: (w) => w.name,
                width: _wDropdown,
              ),
            ),
            const _SubHeader('timing'),
            _PrefRow(
              label: 'emit-interval',
              description: 'how often a frame is emitted, in milliseconds; 33 ≈ 30 fps',
              control: AtomNumberInput(
                value: s.emitInterval.inMilliseconds.toDouble(),
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(
                      emitInterval: Duration(milliseconds: v.round())),
                  setter: p.setSpectrum,
                ),
                decimals: 0,
                min: 8,
                max: 67,
                width: _wNumber,
              ),
            ),
            _PrefRow(
              label: 'attack-smoothing',
              description: 'EMA factor on rising amplitudes (0 none, 1 frozen)',
              control: AtomNumberInput(
                value: s.attackSmoothing,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(attackSmoothing: v.clamp(0, 1)),
                  setter: p.setSpectrum,
                ),
                decimals: 3,
                min: 0,
                max: 1,
                width: _wNumber,
              ),
            ),
            _PrefRow(
              label: 'release-smoothing',
              description: 'EMA factor on falling amplitudes; usually slower than attack',
              control: AtomNumberInput(
                value: s.releaseSmoothing,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(releaseSmoothing: v.clamp(0, 1)),
                  setter: p.setSpectrum,
                ),
                decimals: 3,
                min: 0,
                max: 1,
                width: _wNumber,
              ),
            ),
            const _SubHeader('clipping'),
            _PrefRow(
              label: 'min-db',
              description: 'everything below this level renders as zero',
              control: AtomNumberInput(
                value: s.minDb,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(minDb: v.clamp(-200, s.maxDb - 1)),
                  setter: p.setSpectrum,
                ),
                decimals: 0,
                min: -200,
                max: -10,
                width: _wNumber,
              ),
            ),
            _PrefRow(
              label: 'max-db',
              description: 'everything above this level saturates to one',
              control: AtomNumberInput(
                value: s.maxDb,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: s,
                  newValue: s.copyWith(maxDb: v.clamp(s.minDb + 1, 20)),
                  setter: p.setSpectrum,
                ),
                decimals: 0,
                min: -50,
                max: 20,
                width: _wNumber,
              ),
            ),
          ],
        );
      },
    );
  }
}

class CoverArtSection extends StatelessWidget {
  const CoverArtSection({super.key});
  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrefRow(
          label: 'cover-art-auto',
          description: 'policy for sidecar cover art (folder.jpg etc.)',
          control: StreamBuilder<Cover>(
            stream: p.stream.coverArtAuto,
            builder: (ctx, snap) {
              final cur = snap.data ?? Cover.values.first;
              return AtomDropdown<Cover>(
                value: cur,
                options: Cover.values,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setCoverArtAuto,
                ),
                format: (c) => c.name,
                width: _wDropdown,
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdvancedSection extends StatelessWidget {
  const AdvancedSection({super.key});
  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrefRow(
          label: 'audio-stream-silence',
          description: 'fill output with silence on stalls instead of pausing',
          control: StreamBuilder<bool>(
            stream: p.stream.audioStreamSilence,
            builder: (ctx, snap) {
              final cur = snap.data ?? false;
              return AtomToggle(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setAudioStreamSilence,
                ),
              );
            },
          ),
        ),
        _PrefRow(
          label: 'ao-null-untimed',
          description: 'decode audio as fast as possible (offline analysis)',
          control: StreamBuilder<bool>(
            stream: p.stream.audioNullUntimed,
            builder: (ctx, snap) {
              final cur = snap.data ?? false;
              return AtomToggle(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setAudioNullUntimed,
                ),
              );
            },
          ),
        ),
        _PrefRow(
          label: 'gapless-audio',
          description: 'behaviour at track boundaries: weak, yes or no',
          control: StreamBuilder<Gapless>(
            stream: p.stream.gapless,
            builder: (ctx, snap) {
              final cur = snap.data ?? Gapless.values.first;
              return AtomDropdown<Gapless>(
                value: cur,
                options: Gapless.values,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setGapless,
                ),
                format: (g) => g.name,
                width: _wDropdown,
              );
            },
          ),
        ),
        _PrefRow(
          label: 'prefetch-playlist',
          description: 'decode the next track in advance for instant transitions',
          control: StreamBuilder<bool>(
            stream: p.stream.prefetchPlaylist,
            builder: (ctx, snap) {
              final cur = snap.data ?? false;
              return AtomToggle(
                value: cur,
                onChanged: (v) => PrefsScope.of(ctx).apply(
                  currentValue: cur,
                  newValue: v,
                  setter: p.setPrefetchPlaylist,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Atoms
// ──────────────────────────────────────────────────────────────────────

class _PrefRow extends StatelessWidget {
  final String label;
  final Widget control;
  final String? description;

  const _PrefRow({
    required this.label,
    required this.control,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    // Label + control sit side-by-side at desktop widths; on narrower
    // panels [Wrap] flows the control onto a second line so the row
    // never clips. The description sits below the wrap and pulls its
    // own width from the parent column — left-aligned, no left-pad
    // when wrapped (the label-column reservation only makes sense if
    // the control is on the same row).
    return LayoutBuilder(builder: (ctx, c) {
      final wrapped = c.maxWidth < _wLabel + 240; // rough breakpoint
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 0,
              runSpacing: 4,
              children: [
                SizedBox(
                  width: _wLabel,
                  child: AtomLabel(
                    label,
                    fontSize: ConsoleSkin.sizeSmall,
                    color: ConsoleSkin.fg,
                    mono: true,
                  ),
                ),
                control,
              ],
            ),
            if (description != null)
              Padding(
                padding: EdgeInsets.only(top: 2, left: wrapped ? 0 : _wLabel),
                child: AtomLabel(
                  description!,
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgFaint,
                  wrap: true,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _SubHeader extends StatelessWidget {
  final String label;
  const _SubHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: ConsoleSkin.hairlinePx,
            color: ConsoleSkin.hairline,
          ),
          const SizedBox(width: 8),
          AtomLabel(
            label,
            fontSize: ConsoleSkin.sizeSmall,
            color: ConsoleSkin.accent,
            mono: true,
            letterSpacing: 0.5,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: ConsoleSkin.hairlinePx,
              color: ConsoleSkin.hairline,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 24,
        child: AtomLabel(
          '— loading —',
          fontSize: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgFaint,
          mono: true,
        ),
      );
}
