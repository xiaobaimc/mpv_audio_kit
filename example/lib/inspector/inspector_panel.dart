import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_label.dart';
import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';

/// Right-rail read-out: every state stream the lib exposes that's
/// useful at-a-glance, grouped into sections. Read-only in Phase 2 —
/// interactivity (device picker, mode toggles) lands later.
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _Header(),
        _Hairline(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SourceSection(),
                _OutputSection(),
                _NetworkSection(),
                _ReplayGainSection(),
                _AdvancedSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: AtomLabel(
              'INSPECTOR',
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.accent,
              mono: true,
              letterSpacing: 1.5,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sections ──────────────────────────────────────────────────────────

class _SourceSection extends StatelessWidget {
  const _SourceSection();

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return _Section(
      title: 'SOURCE',
      rows: [
        _kv('title', _stream(p.stream.mediaTitle, _str)),
        _kv('format', _stream(p.stream.fileFormat, _str)),
        _kv('demuxer', _stream(p.stream.currentDemuxer, _str)),
        _kv('size', _stream(p.stream.fileSize, _formatSize)),
        _kv('duration',
            _stream(p.stream.duration, (d) => _formatDuration(d as Duration))),
        _kv('tracks',
            _stream(p.stream.tracks, (t) => '${(t as List).length}')),
      ],
    );
  }
}

class _OutputSection extends StatelessWidget {
  const _OutputSection();

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return _Section(
      title: 'OUTPUT',
      rows: [
        _kv('device', _stream(p.stream.audioDevice,
            (d) => (d as Device).description)),
        _kv('driver', _stream(p.stream.currentAo, _str)),
        _kv('state', _stream(p.stream.audioOutputState,
            (s) => (s as AudioOutputState).name.toUpperCase())),
        _kv('rate',
            _stream(p.stream.audioOutParams, (a) => _formatRate(a as AudioParams))),
        _kv('chans', _stream(p.stream.audioOutParams,
            (a) => _formatChannels(a as AudioParams))),
        _kv('format', _stream(p.stream.audioOutParams,
            (a) => _formatFormat(a as AudioParams))),
        _kv('bitrate', _stream(p.stream.audioBitrate,
            (b) => _formatBitrate(b as double?))),
      ],
    );
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return _Section(
      title: 'NETWORK',
      rows: [
        _kv('via net',
            _stream(p.stream.demuxerViaNetwork, (b) => _yn(b as bool))),
        _kv('cache', _stream(p.stream.cache,
            (c) => _formatCache(c as CacheSettings))),
        _kv('buffer',
            _stream(p.stream.bufferDuration,
                (d) => _formatDuration(d as Duration))),
        _kv('down',
            _stream(p.stream.cacheSpeed, (s) => _formatBps(s as double))),
        _kv('tls',
            _stream(p.stream.tlsVerify, (b) => (b as bool) ? 'verify' : 'off')),
        _kv('timeout',
            _stream(p.stream.networkTimeout,
                (d) => _formatDuration(d as Duration))),
        _kv('paused', _stream(p.stream.pausedForCache,
            (b) => _yn(b as bool))),
      ],
    );
  }
}

class _ReplayGainSection extends StatelessWidget {
  const _ReplayGainSection();

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return _Section(
      title: 'REPLAY-GAIN',
      rows: [
        _kv('mode', _stream(p.stream.replayGain,
            (s) => (s as ReplayGainSettings).mode.name)),
        _kv('preamp', _stream(p.stream.replayGain,
            (s) => _formatDb((s as ReplayGainSettings).preamp))),
        _kv('clip', _stream(p.stream.replayGain,
            (s) => _yn((s as ReplayGainSettings).clip))),
        _kv('fallback', _stream(p.stream.replayGain,
            (s) => _formatDb((s as ReplayGainSettings).fallback))),
        _kv('volgain',
            _stream(p.stream.volumeGain, (g) => _formatDb(g as double))),
      ],
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection();

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return _Section(
      title: 'ADVANCED',
      rows: [
        _kv('exclusive',
            _stream(p.stream.audioExclusive, (b) => _yn(b as bool))),
        _kv('spdif', _stream(p.stream.audioSpdif,
            (s) => _formatSpdif(s as Set<Spdif>))),
        _kv('silence',
            _stream(p.stream.audioStreamSilence, (b) => _yn(b as bool))),
        _kv('prefetch', _stream(p.stream.prefetchState,
            (s) => (s as MpvPrefetchState).name)),
        _kv('gapless', _stream(p.stream.gapless,
            (g) => (g as Gapless).name)),
        _kv('mpv', _stream(p.stream.mpvVersion, _str)),
        _kv('ffmpeg', _stream(p.stream.ffmpegVersion, _str)),
      ],
    );
  }
}

// ─── Atoms ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<_Kv> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ConsoleSkin.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 22,
            color: ConsoleSkin.bgRaised,
            padding: const EdgeInsets.symmetric(horizontal: ConsoleSkin.pad),
            alignment: Alignment.centerLeft,
            child: AtomLabel(
              title,
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.fgDim,
              mono: true,
              letterSpacing: 1.5,
              weight: FontWeight.w500,
            ),
          ),
          ...rows.map((r) => _Row(kv: r)),
        ],
      ),
    );
  }
}

class _Kv {
  final String label;
  final Widget value;
  _Kv(this.label, this.value);
}

_Kv _kv(String label, Widget value) => _Kv(label, value);

class _Row extends StatelessWidget {
  final _Kv kv;
  const _Row({required this.kv});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ConsoleSkin.pad),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: AtomLabel(
                kv.label,
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                mono: true,
              ),
            ),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: kv.value)),
          ],
        ),
      ),
    );
  }
}

// ─── Stream helper ─────────────────────────────────────────────────────

/// Wraps a typed stream + a formatter into a StreamBuilder that paints
/// a mono `AtomLabel`. `formatter` accepts dynamic so the per-row maps
/// can stay compact at the call sites.
Widget _stream<T>(Stream<T> stream, String Function(dynamic) formatter) {
  return StreamBuilder<T>(
    stream: stream,
    builder: (ctx, snap) => AtomLabel(
      snap.hasData ? formatter(snap.data) : '—',
      fontSize: ConsoleSkin.sizeSmall,
      color: ConsoleSkin.fg,
      mono: true,
    ),
  );
}

// ─── Formatters ────────────────────────────────────────────────────────

String _str(dynamic v) {
  final s = v as String;
  return s.isEmpty ? '—' : s;
}

String _yn(bool b) => b ? 'yes' : 'no';

String _formatSize(dynamic v) {
  final bytes = v as int;
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String _formatBitrate(double? bps) {
  if (bps == null || bps <= 0) return '—';
  if (bps < 1000) return '${bps.toStringAsFixed(0)} bps';
  if (bps < 1000000) return '${(bps / 1000).toStringAsFixed(0)} kbps';
  return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
}

String _formatRate(AudioParams a) {
  final r = a.sampleRate;
  return r == null ? '—' : '$r Hz';
}

String _formatChannels(AudioParams a) {
  final n = a.channelCount;
  final c = a.channels;
  if (c != null && n != null) return '${c.mpvValue} ($n)';
  if (n != null) return '$n ch';
  return '—';
}

String _formatFormat(AudioParams a) {
  final f = a.format;
  return f == null ? '—' : f.name;
}

String _formatDb(double db) {
  final sign = db >= 0 ? '+' : '';
  return '$sign${db.toStringAsFixed(1)} dB';
}

String _formatBps(double bps) {
  if (bps <= 0) return '—';
  if (bps < 1024) return '${bps.toStringAsFixed(0)} B/s';
  if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
  return '${(bps / 1024 / 1024).toStringAsFixed(1)} MB/s';
}

String _formatDuration(Duration d) {
  if (d == Duration.zero) return '—';
  if (d.inMilliseconds < 1000) return '${d.inMilliseconds} ms';
  if (d.inSeconds < 60) {
    return '${d.inSeconds}.${(d.inMilliseconds % 1000 ~/ 100)} s';
  }
  if (d.inMinutes < 60) {
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}'
      ':${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

String _formatCache(CacheSettings c) {
  return '${c.mode.name} · ${c.secs.inSeconds}s';
}

String _formatSpdif(Set<Spdif> s) {
  if (s.isEmpty) return 'off';
  return s.map((e) => e.name).join(',');
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Container(
        height: ConsoleSkin.hairlinePx,
        color: ConsoleSkin.hairline,
      );
}
