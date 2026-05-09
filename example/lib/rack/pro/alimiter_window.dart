import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_level_meter.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `alimiter` (brick-wall limiter).
/// Hero element is a scrolling waveform of the post-DSP output with
/// the ceiling drawn as a horizontal hairline — directly cribbed from
/// FabFilter Pro-L 2's main display. The signal portion above the
/// pre-limiter envelope (i.e. the gain reduction the limiter is
/// applying) tints accent so the user sees, frame by frame, exactly
/// where transients are being shaved.
///
/// To the right, a true-peak meter and a small numeric readout of the
/// integrated gain reduction over the visible window (last ~5 s).
///
/// Five knobs below: input gain, ceiling, attack, release, output
/// level. The boolean flags (`asc`, `latency`, `level`) keep their
/// `*Settings` defaults — niche enough to live outside the headline UI.
class AlimiterWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AlimiterWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.alimiter;
        return ProPluginWindow(
          filterName: 'alimiter',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

const double _grMaxDb = 24;
// Window of waveform history shown on screen. Buffer holds one peak
// sample per ring slot, accumulated over the window's tap rate so
// shorter windows show finer detail without changing the slot count.
const int _waveSlots = 480;

double _ampToDb(double v) =>
    20 * (math.log(v.clamp(1e-9, 64.0)) / math.ln10);

double _dbToAmp(double db) => math.pow(10.0, db / 20.0).toDouble();

// ──────────────────────────────────────────────────────────────────────
// Graph — scrolling waveform with ceiling overlay + GR strip.
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final AlimiterSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  // Two peak rings — pre-limiter and post-limiter — drawn on top of
  // each other. The delta highlights where the limiter is biting.
  final _preRing = Float32List(_waveSlots);
  final _postRing = Float32List(_waveSlots);
  int _writeIdx = 0;
  // Notifies the painter; value changes only on each new sample so the
  // CustomPaint repaints in lockstep with incoming audio.
  final _tick = ValueNotifier<int>(0);
  final _truePeakDb = ValueNotifier<double>(-60);
  final _avgGrDb = ValueNotifier<double>(0);

  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;
  // Latest peaks from the two taps, awaiting their pair so both go
  // into the ring at the same write index. Without pairing here,
  // asymmetric tap delivery would offset the two waveforms by one
  // slot and the GR overlay would visibly lag.
  double? _pendingPrePeak;
  double? _pendingPostPeak;

  @override
  void initState() {
    super.initState();
    _preSub = widget.player.stream
        .tap(AudioEffect.alimiter, side: TapSide.pre)
        .listen((pcm) {
      if (!mounted) return;
      _pendingPrePeak = _peak(pcm);
      _tryWrite();
    });
    _postSub = widget.player.stream
        .tap(AudioEffect.alimiter, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      final post = _peak(pcm);
      // True-peak meter tracks the post side directly with a fast
      // attack / slow release.
      final db = post <= 1e-6 ? -60.0 : _ampToDb(post.toDouble());
      final prev = _truePeakDb.value;
      final alpha = db > prev ? 0.7 : 0.05;
      _truePeakDb.value = prev + alpha * (db - prev);
      // Pair with the matching pre-frame to write a slot; if pre
      // hasn't arrived yet we hold the post until it does.
      _pendingPostPeak = post;
      _tryWrite();
    });
  }

  void _tryWrite() {
    final pre = _pendingPrePeak;
    final post = _pendingPostPeak;
    if (pre == null || post == null) return;
    _preRing[_writeIdx] = pre;
    _postRing[_writeIdx] = post;
    _writeIdx = (_writeIdx + 1) % _waveSlots;
    _pendingPrePeak = null;
    _pendingPostPeak = null;
    // Recompute average GR over the visible window — cheap, runs once
    // per emitted sample (tap rate, not audio rate).
    var grSum = 0.0;
    for (var i = 0; i < _waveSlots; i++) {
      final p = _preRing[i];
      final q = _postRing[i];
      if (p > 1e-6 && q > 1e-6) {
        grSum += (_ampToDb(p.toDouble()) - _ampToDb(q.toDouble())).clamp(0.0, _grMaxDb);
      }
    }
    _avgGrDb.value = grSum / _waveSlots;
    _tick.value = _tick.value + 1;
  }

  double _peak(PcmFrame f) {
    var peak = 0.0;
    final s = f.samples;
    for (var i = 0; i < s.length; i++) {
      final a = s[i].abs();
      if (a > peak) peak = a;
    }
    return peak.toDouble();
  }

  @override
  void dispose() {
    _preSub?.cancel();
    _postSub?.cancel();
    _tick.dispose();
    _truePeakDb.dispose();
    _avgGrDb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ceilingDb = _ampToDb(widget.settings.limit);
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WaveformPainter(
                  settings: widget.settings,
                  preRing: _preRing,
                  postRing: _postRing,
                  writeIdx: () => _writeIdx,
                  grDb: _avgGrDb,
                  repaint: Listenable.merge([_tick, _avgGrDb]),
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: AtomLevelMeter(
              source: _truePeakDb,
              sourceInDb: true,
              minDb: -60,
              maxDb: 0,
              redDb: ceilingDb,
              amberDb: ceilingDb - 3,
              numericReadout: true,
              label: 'TP',
              width: 14,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: AtomLevelMeter(
              source: _avgGrDb,
              sourceInDb: true,
              minDb: 0,
              maxDb: 18,
              amberDb: 6,
              redDb: 12,
              direction: MeterDirection.downFromTop,
              numericReadout: true,
              label: 'GR',
              width: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Waveform painter — draws pre-limiter envelope (faint) under the
// post-limiter envelope (bright), plus the ceiling hairline.
// ──────────────────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final AlimiterSettings settings;
  final Float32List preRing;
  final Float32List postRing;
  final int Function() writeIdx;
  final ValueListenable<double> grDb;

  _WaveformPainter({
    required this.settings,
    required this.preRing,
    required this.postRing,
    required this.writeIdx,
    required this.grDb,
    required Listenable repaint,
  }) : super(repaint: repaint);

  // Max strip height, in pixels, capped per the design.
  static const double _grStripMaxPx = 16;
  // GR value (dB) at which the strip reaches full [_grStripMaxPx].
  static const double _grStripFullDb = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);

    // Centerline + symmetric amplitude grid. Centerline uses the
    // emphasised reference style so 0 reads at a glance.
    final mid = plot.top + plot.height / 2;
    final half = plot.height / 2;
    PlotChrome.drawZeroH(canvas, size, mid);
    for (final t in [0.25, 0.5, 0.75]) {
      PlotChrome.drawHGrid(canvas, size, mid - half * t);
      PlotChrome.drawHGrid(canvas, size, mid + half * t);
    }

    // Ceiling lines — top and bottom mirror pair.
    final ceil = settings.limit.clamp(0.001, 1.0);
    final ceilUp = (mid - half * ceil).floorToDouble() + 0.5;
    final ceilDn = (mid + half * ceil).floorToDouble() + 0.5;
    final ceilPaint = Paint()
      ..color = ConsoleSkin.accentDim
      ..strokeWidth = 1
      ..isAntiAlias = true;
    canvas.drawLine(
        Offset(plot.left, ceilUp), Offset(plot.right, ceilUp), ceilPaint);
    canvas.drawLine(
        Offset(plot.left, ceilDn), Offset(plot.right, ceilDn), ceilPaint);

    // Walk the ring in time order — oldest sample at writeIdx, newest
    // at writeIdx-1. Map slot index → x linearly across the plot rect.
    final start = writeIdx();
    Path envelope(Float32List ring) {
      final p = Path();
      for (var i = 0; i < _waveSlots; i++) {
        final src = (start + i) % _waveSlots;
        final amp = ring[src].clamp(0.0, 1.0);
        final x = plot.left + plot.width * i / (_waveSlots - 1);
        final y = mid - half * amp;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      // Close back through the bottom mirror so we can fill.
      for (var i = _waveSlots - 1; i >= 0; i--) {
        final src = (start + i) % _waveSlots;
        final amp = ring[src].clamp(0.0, 1.0);
        final x = plot.left + plot.width * i / (_waveSlots - 1);
        final y = mid + half * amp;
        p.lineTo(x, y);
      }
      p.close();
      return p;
    }

    // Pre envelope first (under, faint).
    canvas.drawPath(
      envelope(preRing),
      Paint()..color = ConsoleSkin.fgFaint,
    );
    // Post envelope (the limited signal — accent).
    canvas.drawPath(
      envelope(postRing),
      Paint()..color = ConsoleSkin.accent,
    );

    // GR strip — bright red bar growing downward from the plot top,
    // height proportional to current GR. Capped at [_grStripMaxPx].
    final gr = grDb.value.clamp(0.0, _grMaxDb);
    if (gr > 0.05) {
      final h = (_grStripMaxPx * (gr / _grStripFullDb)).clamp(0.0, _grStripMaxPx);
      canvas.drawRect(
        Rect.fromLTWH(plot.left, plot.top, plot.width, h),
        Paint()..color = ConsoleSkin.meterRed.withValues(alpha: 0.85),
      );
      // Hairline border under the strip to detach it from the envelope.
      canvas.drawLine(
        Offset(plot.left, plot.top + h + 0.5),
        Offset(plot.right, plot.top + h + 0.5),
        Paint()
          ..color = ConsoleSkin.meterRed
          ..strokeWidth = 1
          ..isAntiAlias = false,
      );
    }

    // Amplitude labels along the right gutter (peak normalised to 1.0).
    PlotChrome.drawYLabelRight(canvas, size, mid, '0',
        color: ConsoleSkin.fgDim);
    PlotChrome.drawYLabelRight(canvas, size, mid - half * 0.5, '0.5');
    PlotChrome.drawYLabelRight(canvas, size, mid + half * 0.5, '0.5');
    PlotChrome.drawYLabelRight(canvas, size, plot.top, '1');
    PlotChrome.drawYLabelRight(canvas, size, plot.bottom, '1');
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.settings != settings;
}

// ──────────────────────────────────────────────────────────────────────
// Controls — five knobs.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final AlimiterSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AlimiterSettings next) {
    player.updateAudioEffects((b) => b.copyWith(alimiter: next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AtomKnob(
            // ffmpeg's AVOption table for `alimiter.level_in` reports
            // an inverted `(min=64, max=None)` pair — codegen-side
            // bug in `parse.py`. Until that's fixed, fall back to the
            // documented level-gain range used by every other amp
            // knob in this build.
            value: _ampToDb(settings.level_in),
            min: -36,
            max: 36,
            defaultValue: _ampToDb(AlimiterSettings.level_inDefault),
            onChanged: (db) => _apply(settings.copyWith(
              level_in: _dbToAmp(db).clamp(0.015625, 64.0),
            )),
            label: 'in dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            // Engine spec: `limit` ∈ [0.0625, 1.0] (≈ -24..0 dB).
            // Visual range matches spec exactly so the knob covers
            // every legal value without dead zones.
            value: _ampToDb(settings.limit),
            min: _ampToDb(AlimiterSettings.limitMin),
            max: 0,
            defaultValue: _ampToDb(AlimiterSettings.limitDefault),
            onChanged: (db) => _apply(settings.copyWith(
              limit: _dbToAmp(db).clamp(
                AlimiterSettings.limitMin,
                AlimiterSettings.limitMax,
              ),
            )),
            label: 'ceil dB',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.attack,
            min: AlimiterSettings.attackMin,
            max: AlimiterSettings.attackMax,
            defaultValue: AlimiterSettings.attackDefault,
            onChanged: (v) => _apply(settings.copyWith(attack: v)),
            label: 'atk ms',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.release,
            // Spec release caps at 8000 ms; we cap visual at 2000 for
            // resolution. Engine clamp uses spec.
            min: 1,
            max: 2000,
            defaultValue: AlimiterSettings.releaseDefault,
            onChanged: (v) => _apply(settings.copyWith(
              release: v.clamp(
                AlimiterSettings.releaseMin,
                AlimiterSettings.releaseMax,
              ),
            )),
            label: 'rel ms',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            // Same parser-bug workaround as `level_in` above.
            value: _ampToDb(settings.level_out),
            min: -36,
            max: 36,
            defaultValue: _ampToDb(AlimiterSettings.level_outDefault),
            onChanged: (db) => _apply(settings.copyWith(
              level_out: _dbToAmp(db).clamp(0.015625, 64.0),
            )),
            label: 'out dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
        ],
      ),
    );
  }
}
