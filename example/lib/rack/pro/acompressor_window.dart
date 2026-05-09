import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_level_meter.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `acompressor` filter. Hero element
/// is the dB-in / dB-out knee plot — the universal compressor diagram
/// (FabFilter Pro-C, Logic Compressor, Waves CLA all use the same
/// shape). A ball travels along the curve in real time at the live
/// input level, with vertical input + GR meters flanking the plot.
///
/// Six knobs below: threshold, ratio, attack, release, knee, makeup.
/// The remaining filter parameters (detection, link, mode, mix,
/// level_in, level_sc) keep their `*Settings` defaults — they're rarely
/// tweaked from the diagram and clutter the surface; consumers who
/// need them can write through `setAudioEffects` directly.
class AcompressorWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AcompressorWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.acompressor;
        return ProPluginWindow(
          filterName: 'acompressor',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Math helpers — lavfi exposes threshold / makeup / level_in as linear
// amplitude factors; the knee plot is dB-natural so we convert at the
// boundary.
// ──────────────────────────────────────────────────────────────────────

const double _dbFloor = -60;
const double _dbCeil = 0;
const double _meterMinDb = -60;
const double _grMaxDb = 24;

double _ampToDb(double v) =>
    20 * (math.log(v.clamp(1e-9, 64.0)) / math.ln10);

double _dbToAmp(double db) => math.pow(10.0, db / 20.0).toDouble();

/// Soft-knee compressor transfer function in dB. Standard model — RBJ
/// audio-EQ-cookbook style. [knee] is in dB (linear `knee` from lavfi
/// is treated as a width: a value of `2.82843` ≈ `2·sqrt(2)` ≈ a 9 dB
/// knee width, the lavfi default).
double _kneeOutDb(
  double inDb, {
  required double thresholdDb,
  required double ratio,
  required double kneeDb,
  required double makeupDb,
}) {
  final diff = inDb - thresholdDb;
  double out;
  if (kneeDb > 0 && (2 * diff).abs() <= kneeDb) {
    // Quadratic blend across the knee region.
    final factor = (1.0 / ratio - 1.0) / (2.0 * kneeDb);
    out = inDb + factor * math.pow(diff + kneeDb / 2, 2).toDouble();
  } else if (diff > kneeDb / 2) {
    out = thresholdDb + diff / ratio;
  } else {
    out = inDb;
  }
  return out + makeupDb;
}

double _xOfDb(double db, Size size) {
  final plot = PlotChrome.plotRect(size);
  return plot.left +
      plot.width *
          ((db - _dbFloor) / (_dbCeil - _dbFloor)).clamp(0.0, 1.0);
}

double _yOfDb(double db, Size size) {
  final plot = PlotChrome.plotRect(size);
  return plot.top +
      plot.height *
          (1 - ((db - _dbFloor) / (_dbCeil - _dbFloor)).clamp(0.0, 1.0));
}

// ──────────────────────────────────────────────────────────────────────
// Graph — knee plot + I/O meters. Subscribes to the per-filter PCM
// taps (pre + post) to drive the level meters and the live ball
// scrolling along the curve. Both meters use simple peak with an
// asymmetric EMA so they snap up on transients and decay smoothly.
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final AcompressorSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

/// Slot count for the scrolling waveform strip at the bottom of the
/// knee plot.
const int _waveSlots = 240;

class _GraphState extends State<_Graph> {
  // Peak input / output levels in dB. Drive the IN level meter and
  // the live ball position on the knee plot — both want "where is the
  // loudest moment right now" semantics.
  final _inDb = ValueNotifier<double>(_meterMinDb);
  final _outDb = ValueNotifier<double>(_meterMinDb);
  // Short-term RMS levels in dB. Used by the GR meter — peak-vs-peak
  // GR mis-reports under-report on real music because transients
  // routinely escape the comp's attack and latch the post-tap peak
  // back to the input peak, hiding the meaningful gain reduction.
  // RMS averages those transients out so the meter reflects the
  // compressor's actual average level reduction.
  final _grDb = ValueNotifier<double>(0);
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;
  // EMA state — kept here, not in the notifiers, so the smoothing math
  // sees the previous frame's value without bouncing through setState.
  double _inPeakSmoothed = _meterMinDb;
  double _outPeakSmoothed = _meterMinDb;
  double _inRmsSmoothed = _meterMinDb;
  double _outRmsSmoothed = _meterMinDb;

  // Pre / post peak rings for the bottom-of-plot scrolling waveform.
  final _preRing = Float32List(_waveSlots);
  final _postRing = Float32List(_waveSlots);
  int _writeIdx = 0;
  final _waveTick = ValueNotifier<int>(0);
  double? _pendingPrePeak;
  double? _pendingPostPeak;

  @override
  void initState() {
    super.initState();
    _preSub = widget.player.stream
        .tap(AudioEffect.acompressor, side: TapSide.pre)
        .listen((pcm) {
      if (!mounted) return;
      _inPeakSmoothed = _peakDb(pcm, _inPeakSmoothed);
      _inRmsSmoothed = _rmsDb(pcm, _inRmsSmoothed);
      _inDb.value = _inPeakSmoothed;
      _grDb.value =
          (_inRmsSmoothed - _outRmsSmoothed).clamp(0.0, _grMaxDb);
      _pendingPrePeak = _peakAmp(pcm);
      _tryWriteRing();
    });
    _postSub = widget.player.stream
        .tap(AudioEffect.acompressor, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      _outPeakSmoothed = _peakDb(pcm, _outPeakSmoothed);
      _outRmsSmoothed = _rmsDb(pcm, _outRmsSmoothed);
      _outDb.value = _outPeakSmoothed;
      _grDb.value =
          (_inRmsSmoothed - _outRmsSmoothed).clamp(0.0, _grMaxDb);
      _pendingPostPeak = _peakAmp(pcm);
      _tryWriteRing();
    });
  }

  /// Linear peak (0..1) over a tap frame.
  double _peakAmp(PcmFrame f) {
    var peak = 0.0;
    final s = f.samples;
    for (var i = 0; i < s.length; i++) {
      final a = s[i].abs();
      if (a > peak) peak = a;
    }
    return peak.toDouble();
  }

  /// Pair pre + post peaks into the ring at the same index so the
  /// envelopes don't slip relative to each other.
  void _tryWriteRing() {
    final pre = _pendingPrePeak;
    final post = _pendingPostPeak;
    if (pre == null || post == null) return;
    _preRing[_writeIdx] = pre;
    _postRing[_writeIdx] = post;
    _writeIdx = (_writeIdx + 1) % _waveSlots;
    _pendingPrePeak = null;
    _pendingPostPeak = null;
    _waveTick.value = _waveTick.value + 1;
  }

  @override
  void dispose() {
    _preSub?.cancel();
    _postSub?.cancel();
    _inDb.dispose();
    _outDb.dispose();
    _grDb.dispose();
    _waveTick.dispose();
    super.dispose();
  }

  /// Peak-detect a frame and feed it into an asymmetric EMA. Snappy on
  /// transients (attack 0.7), slow on decay (release 0.05). Range
  /// clamped to [_meterMinDb, 0] so the visualiser never reports
  /// "louder than digital max".
  double _peakDb(PcmFrame f, double prev) {
    var peak = 0.0;
    final s = f.samples;
    for (var i = 0; i < s.length; i++) {
      final a = s[i].abs();
      if (a > peak) peak = a;
    }
    final db = peak <= 1e-6 ? _meterMinDb : _ampToDb(peak.toDouble());
    final clamped = db.clamp(_meterMinDb, _dbCeil);
    final alpha = clamped > prev ? 0.7 : 0.05;
    return prev + alpha * (clamped - prev);
  }

  /// Short-term RMS in dB with symmetric medium-fast smoothing.
  /// Tracks energy-averaged level instead of peaks, so transients
  /// don't dominate. Used for GR computation only — the level-meter
  /// readings still come from [_peakDb] above to keep their "loudest
  /// moment" semantics.
  double _rmsDb(PcmFrame f, double prev) {
    final s = f.samples;
    if (s.isEmpty) return prev;
    var sumSq = 0.0;
    for (var i = 0; i < s.length; i++) {
      final v = s[i];
      sumSq += v * v;
    }
    final rms = math.sqrt(sumSq / s.length);
    final db = rms <= 1e-6 ? _meterMinDb : _ampToDb(rms.toDouble());
    final clamped = db.clamp(_meterMinDb, _dbCeil);
    // Symmetric ballistics around 0.3 — fast enough to react to the
    // comp attacking / releasing, slow enough to filter sample-rate
    // noise.
    return prev + 0.3 * (clamped - prev);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: AtomLevelMeter(
              source: _inDb,
              sourceInDb: true,
              minDb: _meterMinDb,
              maxDb: 0,
              amberDb: -12,
              redDb: -3,
              numericReadout: true,
              label: 'IN',
              width: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _KneePainter(
                  settings: widget.settings,
                  inDb: _inDb,
                  outDb: _outDb,
                  preRing: _preRing,
                  postRing: _postRing,
                  writeIdx: () => _writeIdx,
                  waveTick: _waveTick,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: AtomLevelMeter(
              source: _grDb,
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
// Knee plot painter
// ──────────────────────────────────────────────────────────────────────

class _KneePainter extends CustomPainter {
  final AcompressorSettings settings;
  final ValueListenable<double> inDb;
  final ValueListenable<double> outDb;
  final Float32List preRing;
  final Float32List postRing;
  final int Function() writeIdx;
  final ValueListenable<int> waveTick;

  _KneePainter({
    required this.settings,
    required this.inDb,
    required this.outDb,
    required this.preRing,
    required this.postRing,
    required this.writeIdx,
    required this.waveTick,
  }) : super(repaint: Listenable.merge([inDb, outDb, waveTick]));

  // Bottom scrolling waveform takes ~30% of plot height.
  static const double _waveStripFrac = 0.30;

  // Major gridlines = labeled axis ticks. Every 12 dB so the user
  // sees the same number of labels on both axes regardless of canvas
  // size. Minor gridlines fill the 6 dB midpoints with a dimmer
  // colour for sub-divisions; they have no label and no tick mark.
  static const _gridDbMajor = [-60, -48, -36, -24, -12, 0];
  static const _gridDbMinor = [-54, -42, -30, -18, -6];

  double get _thresholdDb => _ampToDb(settings.threshold);
  double get _makeupDb => _ampToDb(settings.makeup);
  // lavfi knee is a linear "factor"; 1 = hard, 8 ≈ 18 dB wide. Treat
  // its dB equivalent as the visual knee width so the curve smoothing
  // stays proportional to the knob.
  double get _kneeDb => _ampToDb(settings.knee.clamp(1.0, 8.0));

  double _y(double db, Size size) => _yOfDb(db, size);
  double _x(double db, Size size) => _xOfDb(db, size);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);
    final plot = PlotChrome.plotRect(size);

    // Two-tier grid: major (labeled, visibly brighter) every 12 dB,
    // minor (un-labeled, very dim) every 6 dB between them. Both X
    // and Y get the same treatment so the plane reads as a regular
    // lattice. The brightness gap between the two tiers is what lets
    // the eye trust which gridline a bottom-axis label belongs to.
    for (final db in _gridDbMinor) {
      PlotChrome.drawVGrid(canvas, size, _x(db.toDouble(), size),
          color: ConsoleSkin.hairline);
      PlotChrome.drawHGrid(canvas, size, _y(db.toDouble(), size),
          color: ConsoleSkin.hairline);
    }
    for (final db in _gridDbMajor) {
      PlotChrome.drawVGrid(canvas, size, _x(db.toDouble(), size),
          color: ConsoleSkin.fgFaint);
      PlotChrome.drawHGrid(canvas, size, _y(db.toDouble(), size),
          color: ConsoleSkin.fgFaint);
    }

    // Diagonal y=x reference (no compression) — drawn faintly so the
    // user sees how much the curve deviates.
    canvas.drawLine(
      Offset(_x(_dbFloor, size), _y(_dbFloor, size)),
      Offset(_x(_dbCeil, size), _y(_dbCeil, size)),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    // Threshold marker — vertical hairline at threshold_dB, clipped
    // to the plot rect.
    final tx = _x(_thresholdDb, size);
    // Active-section tint: above-threshold zone gets a faint accent
    // wash so the user sees where the comp is actually working.
    if (inDb.value > _thresholdDb) {
      canvas.drawRect(
        Rect.fromLTRB(tx, plot.top, plot.right, plot.bottom),
        Paint()..color = ConsoleSkin.accent.withValues(alpha: 0.08),
      );
    }
    canvas.drawLine(
      Offset(tx, plot.top),
      Offset(tx, plot.bottom),
      Paint()
        ..color = ConsoleSkin.accentDim
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    // Knee curve — sample the transfer function across the input range.
    final curve = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final inputDb = _dbFloor + t * (_dbCeil - _dbFloor);
      final outDb = _kneeOutDb(
        inputDb,
        thresholdDb: _thresholdDb,
        ratio: settings.ratio,
        kneeDb: _kneeDb,
        makeupDb: _makeupDb,
      );
      final x = _x(inputDb, size);
      final y = _y(outDb, size);
      if (i == 0) {
        curve.moveTo(x, y);
      } else {
        curve.lineTo(x, y);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = ConsoleSkin.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // Live ball — riding along the curve at (input_dB, output_dB).
    // Uses the post-tap output value so the ball reflects what the
    // engine actually produced (not just our model). When the comp is
    // bypassed (enabled=false) the curve and the ball coincide on
    // y=x, which is the right visual.
    final iDb = inDb.value;
    if (iDb > _meterMinDb + 0.5) {
      final oDb = outDb.value;
      final bx = _x(iDb, size);
      final by = _y(oDb, size);
      canvas.drawCircle(
        Offset(bx, by),
        5,
        Paint()..color = ConsoleSkin.accentHot,
      );
      canvas.drawCircle(
        Offset(bx, by),
        5,
        Paint()
          ..color = ConsoleSkin.fg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..isAntiAlias = true,
      );
    }

    _drawWaveformStrip(canvas, plot);
    _drawAxisLabels(canvas, size);
  }

  /// Bottom strip — pre envelope (faint grey) under post envelope (accent).
  /// Reads pre/post peak rings and renders one slot per pixel column.
  void _drawWaveformStrip(Canvas canvas, Rect plot) {
    final stripH = plot.height * _waveStripFrac;
    final stripTop = plot.bottom - stripH;
    final mid = stripTop + stripH / 2;
    final half = stripH / 2;
    if (stripH <= 4) return;

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

    canvas.drawPath(
      envelope(preRing),
      Paint()..color = ConsoleSkin.fgFaint,
    );
    canvas.drawPath(
      envelope(postRing),
      Paint()..color = ConsoleSkin.accent.withValues(alpha: 0.85),
    );
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    // Axis labels live in the PlotChrome gutters — bottom for X, right
    // for Y — never inside the plot rect. Tick marks anchor each
    // label to its gridline value at the pixel. One label per major
    // gridline, so the user never sees an unlabeled major.
    for (final db in _gridDbMajor) {
      PlotChrome.drawXLabel(
          canvas, size, _x(db.toDouble(), size), '$db');
      PlotChrome.drawYLabelRight(
          canvas, size, _y(db.toDouble(), size), '$db');
    }
    // Threshold label sits to the right of its marker line, top of
    // the plot, in the same dim accent the marker uses. Drawn
    // separately from the regular axis labels because it lives INSIDE
    // the plot (anchored to the threshold line, not the axis).
    final tx = _x(_thresholdDb, size);
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
    ))
      ..pushStyle(ui.TextStyle(
          color: ConsoleSkin.accentDim, fontSize: ConsoleSkin.sizeTiny))
      ..addText('THR ${_thresholdDb.toStringAsFixed(0)}');
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 64));
    canvas.drawParagraph(p, Offset(tx + 4, 4));
  }

  @override
  bool shouldRepaint(_KneePainter old) => old.settings != settings;
}

// ──────────────────────────────────────────────────────────────────────
// Controls — six knobs in a single row. Threshold and makeup convert
// to/from dB for the user, lavfi-side they're stored as linear gain.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final AcompressorSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AcompressorSettings next) {
    player.updateAudioEffects((b) => b.copyWith(acompressor: next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Threshold: stored linear, displayed in dB. Visual knob
          // covers -60..0 dB (full musical range); engine bounds come
          // from the codegen consts so the assert in `toFilterString`
          // can't fire.
          AtomKnob(
            value: _ampToDb(settings.threshold),
            min: -60,
            max: 0,
            defaultValue: _ampToDb(AcompressorSettings.thresholdDefault),
            onChanged: (db) => _apply(settings.copyWith(
              threshold: _dbToAmp(db).clamp(
                AcompressorSettings.thresholdMin,
                AcompressorSettings.thresholdMax,
              ),
            )),
            label: 'thr dB',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.ratio,
            min: AcompressorSettings.ratioMin,
            max: AcompressorSettings.ratioMax,
            defaultValue: AcompressorSettings.ratioDefault,
            onChanged: (v) => _apply(settings.copyWith(ratio: v)),
            label: 'ratio',
            format: (v) => '${v.toStringAsFixed(1)}:1',
            size: 70,
          ),
          const SizedBox(width: 16),
          // Attack / release: spec ranges (0.01..2000 ms, 0.01..9000 ms)
          // are wider than musical resolution allows on a single knob.
          // Visual range tightened to typical comp values; engine
          // clamp uses spec bounds so the asserts can't fire.
          AtomKnob(
            value: settings.attack,
            min: 0.1,
            max: 200,
            defaultValue: AcompressorSettings.attackDefault,
            onChanged: (v) => _apply(settings.copyWith(
              attack: v.clamp(
                AcompressorSettings.attackMin,
                AcompressorSettings.attackMax,
              ),
            )),
            label: 'atk ms',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.release,
            min: 1,
            max: 2000,
            defaultValue: AcompressorSettings.releaseDefault,
            onChanged: (v) => _apply(settings.copyWith(
              release: v.clamp(
                AcompressorSettings.releaseMin,
                AcompressorSettings.releaseMax,
              ),
            )),
            label: 'rel ms',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.knee,
            min: AcompressorSettings.kneeMin,
            max: AcompressorSettings.kneeMax,
            defaultValue: AcompressorSettings.kneeDefault,
            onChanged: (v) => _apply(settings.copyWith(knee: v)),
            label: 'knee',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.makeup),
            min: -12,
            max: 24,
            defaultValue: 0,
            bipolar: true,
            onChanged: (db) => _apply(settings.copyWith(
              makeup: _dbToAmp(db).clamp(
                AcompressorSettings.makeupMin,
                AcompressorSettings.makeupMax,
              ),
            )),
            label: 'makeup',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
        ],
      ),
    );
  }
}
