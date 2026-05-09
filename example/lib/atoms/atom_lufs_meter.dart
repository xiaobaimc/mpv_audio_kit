import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../skin/console_skin.dart';

/// Real-time loudness dashboard fed from a [PcmFrame] stream.
///
/// Computes three running LUFS-like figures from the same post-DSP
/// PCM tap:
/// - **Momentary** — average power over the most recent ~400 ms.
/// - **Short** — average over the most recent ~3 s.
/// - **Integrated** — running average since `reset()` was last called.
///
/// **Caveat:** these figures approximate ITU-R BS.1770 / EBU R128 by
/// using broadband RMS rather than the K-weighted filter chain
/// (pre-filter + RLB + RMS + gating) the spec mandates. The display
/// is therefore directionally correct (you can see momentary peaks,
/// integrated trend) but should not be cited as a compliant
/// measurement. For legally-conformant LUFS, read the engine's own
/// `loudnorm` / `ebur128` metadata via mpv property observers.
///
/// Visually mirrors Youlean Loudness Meter / TC Electronic LM2 — three
/// horizontal numeric readouts with a tall integrated bar on the right
/// and a true-peak strip above. Compact enough to fit inside a pro
/// window's hero area.
class AtomLufsMeter extends StatefulWidget {
  final Stream<PcmFrame> source;
  // Optional target LUFS — when provided the integrated bar grows a
  // hairline at this level so the user reads "how far am I from spec
  // target" at a glance.
  final double? targetLufs;

  const AtomLufsMeter({
    super.key,
    required this.source,
    this.targetLufs,
  });

  @override
  State<AtomLufsMeter> createState() => _AtomLufsMeterState();
}

class _AtomLufsMeterState extends State<AtomLufsMeter> {
  static const double _floor = -60;
  static const double _ceiling = 0;

  final _momentary = ValueNotifier<double>(_floor);
  final _short = ValueNotifier<double>(_floor);
  final _integrated = ValueNotifier<double>(_floor);
  final _truePeak = ValueNotifier<double>(_floor);

  // Sliding-window RMS state. We keep frame energies (mean square) in
  // queues, sized to the desired window in seconds; on each emit we
  // pop the front when the queue is older than the window.
  final List<_FrameEnergy> _momentaryQ = [];
  final List<_FrameEnergy> _shortQ = [];
  // Integrated state — we maintain a running sum for legality of cheap
  // average updates without rescanning.
  double _integratedSumMs = 0;
  double _integratedSumE = 0;

  Duration _now = Duration.zero;
  StreamSubscription<PcmFrame>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe(widget.source);
  }

  @override
  void didUpdateWidget(covariant AtomLufsMeter old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      _sub?.cancel();
      _reset();
      _subscribe(widget.source);
    }
  }

  void _subscribe(Stream<PcmFrame> src) {
    _sub = src.listen((pcm) {
      if (!mounted) return;
      final frame = _FrameEnergy.from(pcm, _now);
      _now += pcm.timestamp - _now;
      _push(_momentaryQ, frame, const Duration(milliseconds: 400));
      _push(_shortQ, frame, const Duration(seconds: 3));
      _integratedSumMs += frame.durationMs;
      _integratedSumE += frame.meanSquare * frame.durationMs;

      _momentary.value = _windowDb(_momentaryQ);
      _short.value = _windowDb(_shortQ);
      _integrated.value = _integratedSumMs > 0
          ? _toDb(_integratedSumE / _integratedSumMs)
          : _floor;
      // Fast-attack / slow-release true peak.
      final tpDb = frame.peakDb;
      final prev = _truePeak.value;
      _truePeak.value = tpDb > prev ? tpDb : prev + 0.05 * (tpDb - prev);
    });
  }

  void _push(List<_FrameEnergy> q, _FrameEnergy frame, Duration window) {
    q.add(frame);
    final cutoff = _now - window;
    while (q.isNotEmpty && q.first.t < cutoff) {
      q.removeAt(0);
    }
  }

  double _windowDb(List<_FrameEnergy> q) {
    if (q.isEmpty) return _floor;
    var totalMs = 0.0;
    var totalE = 0.0;
    for (final f in q) {
      totalMs += f.durationMs;
      totalE += f.meanSquare * f.durationMs;
    }
    if (totalMs <= 0) return _floor;
    return _toDb(totalE / totalMs);
  }

  static double _toDb(double meanSquare) {
    if (meanSquare <= 1e-12) return _floor;
    // Scaled to LUFS-ish: subtract -0.691 dB calibration term ITU-R
    // BS.1770 introduces. Skipping the K-weighting filter, so the
    // value is broadband RMS in dBFS minus 0.691.
    return (10 * (math.log(meanSquare) / math.ln10) - 0.691)
        .clamp(_floor, _ceiling);
  }

  void _reset() {
    _momentaryQ.clear();
    _shortQ.clear();
    _integratedSumMs = 0;
    _integratedSumE = 0;
    _now = Duration.zero;
    _momentary.value = _floor;
    _short.value = _floor;
    _integrated.value = _floor;
    _truePeak.value = _floor;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _momentary.dispose();
    _short.dispose();
    _integrated.dispose();
    _truePeak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column — three numeric readouts, vertically stacked.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NumericReadout(
                  label: 'momentary',
                  value: _momentary,
                ),
                _NumericReadout(
                  label: 'short-term',
                  value: _short,
                ),
                _NumericReadout(
                  label: 'integrated',
                  value: _integrated,
                  highlight: true,
                ),
                if (widget.targetLufs != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'target ${widget.targetLufs!.toStringAsFixed(1)} LUFS',
                      style: const TextStyle(
                        fontFamily: ConsoleSkin.fontMono,
                        fontSize: ConsoleSkin.sizeTiny,
                        color: ConsoleSkin.fgDim,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Integrated bar — tall vertical strip.
          SizedBox(
            width: 28,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _IntegratedBarPainter(
                  value: _integrated,
                  target: widget.targetLufs,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // True-peak — narrow strip on the right.
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _TruePeakPainter(value: _truePeak),
                      size: Size.infinite,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'TP',
                  style: TextStyle(
                    fontFamily: ConsoleSkin.fontMono,
                    fontSize: ConsoleSkin.sizeTiny,
                    color: ConsoleSkin.fgDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameEnergy {
  final Duration t;
  final double durationMs;
  final double meanSquare;
  final double peakDb;

  _FrameEnergy({
    required this.t,
    required this.durationMs,
    required this.meanSquare,
    required this.peakDb,
  });

  factory _FrameEnergy.from(PcmFrame pcm, Duration t) {
    final s = pcm.samples;
    final samplesPerChannel = pcm.samplesPerChannel;
    if (samplesPerChannel <= 0 || pcm.sampleRate <= 0) {
      return _FrameEnergy(
        t: t,
        durationMs: 0,
        meanSquare: 0,
        peakDb: -60,
      );
    }
    var sumSq = 0.0;
    var peak = 0.0;
    for (var i = 0; i < s.length; i++) {
      final v = s[i];
      sumSq += v * v;
      if (v.abs() > peak) peak = v.abs();
    }
    final ms = (samplesPerChannel * 1000.0) / pcm.sampleRate;
    final mean = sumSq / s.length;
    final pkDb = peak <= 1e-9
        ? -60.0
        : (20 * (math.log(peak.toDouble()) / math.ln10)).clamp(-60.0, 0.0);
    return _FrameEnergy(
      t: t,
      durationMs: ms,
      meanSquare: mean.toDouble(),
      peakDb: pkDb,
    );
  }
}

class _NumericReadout extends StatelessWidget {
  final String label;
  final ValueListenable<double> value;
  final bool highlight;

  const _NumericReadout({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: value,
      builder: (ctx, v, _) {
        final text = v <= -59.5 ? '-∞' : v.toStringAsFixed(1);
        return Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: ConsoleSkin.fontMono,
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgDim,
                ),
              ),
            ),
            Text(
              text,
              style: TextStyle(
                fontFamily: ConsoleSkin.fontMono,
                fontSize: highlight ? 22 : 16,
                color: highlight ? ConsoleSkin.accent : ConsoleSkin.fg,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'LUFS',
              style: TextStyle(
                fontFamily: ConsoleSkin.fontMono,
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IntegratedBarPainter extends CustomPainter {
  final ValueListenable<double> value;
  final double? target;
  _IntegratedBarPainter({required this.value, this.target})
      : super(repaint: value);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bg);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = ConsoleSkin.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );
    const minDb = -60.0;
    const maxDb = 0.0;
    double yOf(double db) =>
        size.height *
        (1 - ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0));
    final v = value.value.clamp(minDb, maxDb);
    final top = yOf(v);
    final c = v >= -3
        ? ConsoleSkin.meterRed
        : v >= -12
            ? ConsoleSkin.meterAmber
            : ConsoleSkin.meterGreen;
    canvas.drawRect(
      Rect.fromLTWH(2, top, size.width - 4, size.height - top),
      Paint()..color = c,
    );
    // Target hairline.
    if (target != null) {
      final ty = yOf(target!).floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(0, ty),
        Offset(size.width, ty),
        Paint()
          ..color = ConsoleSkin.accent
          ..strokeWidth = 1
          ..isAntiAlias = true,
      );
    }
    // Scale ticks every 6 dB.
    final tickPaint = Paint()
      ..color = ConsoleSkin.fgFaint
      ..strokeWidth = ConsoleSkin.hairlinePx
      ..isAntiAlias = false;
    for (final tick in [-48, -36, -24, -18, -12, -6, -3, 0]) {
      final ty = yOf(tick.toDouble());
      canvas.drawLine(Offset(0, ty), Offset(3, ty), tickPaint);
    }
  }

  @override
  bool shouldRepaint(_IntegratedBarPainter old) => old.target != target;
}

class _TruePeakPainter extends CustomPainter {
  final ValueListenable<double> value;
  _TruePeakPainter({required this.value}) : super(repaint: value);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bg);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = ConsoleSkin.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );
    const minDb = -60.0;
    const maxDb = 0.0;
    final db = value.value.clamp(minDb, maxDb);
    final t = (db - minDb) / (maxDb - minDb);
    final h = size.height * t;
    final top = size.height - h;
    final c = db >= -1
        ? ConsoleSkin.meterRed
        : db >= -6
            ? ConsoleSkin.meterAmber
            : ConsoleSkin.meterGreen;
    canvas.drawRect(
      Rect.fromLTWH(2, top, size.width - 4, h),
      Paint()..color = c,
    );
  }

  @override
  bool shouldRepaint(_TruePeakPainter old) => false;
}
