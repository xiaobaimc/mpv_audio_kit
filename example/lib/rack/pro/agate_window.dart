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

/// Pro-style window for the lavfi `agate` (noise gate). Mirror image
/// of `acompressor`: same dB-in / dB-out hero plot, same level + GR
/// meters, but the transfer function is inverted — below the threshold
/// the signal is **attenuated** by `range` dB, above it passes through.
/// This is the universal gate diagram (FabFilter Pro-G, Drawmer, every
/// SSL channel-strip emulation).
///
/// Seven knobs below: threshold, range, ratio, attack, release, knee,
/// makeup. The remaining filter parameters (detection, link, mode)
/// keep their `*Settings` defaults — niche enough to live outside the
/// headline UI.
class AgateWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AgateWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.agate;
        return ProPluginWindow(
          filterName: 'agate',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

const double _dbFloor = -60;
const double _dbCeil = 0;
const double _meterMinDb = -60;
const double _grMaxDb = 24;

double _ampToDb(double v) =>
    20 * (math.log(v.clamp(1e-9, 64.0)) / math.ln10);

double _dbToAmp(double db) => math.pow(10.0, db / 20.0).toDouble();

/// Soft-knee gate transfer function in dB. Below threshold the signal
/// is attenuated by `attenDb` (the range, in dB); above threshold it
/// passes intact. Smoothing across the knee keeps the curve continuous
/// instead of stepping at threshold.
double _gateOutDb(
  double inDb, {
  required double thresholdDb,
  required double attenDb,
  required double kneeDb,
  required double makeupDb,
}) {
  final diff = inDb - thresholdDb;
  double out;
  if (kneeDb > 0 && (2 * diff).abs() <= kneeDb) {
    // Quadratic smooth blend across the knee. At diff = -knee/2 it
    // reduces to (input - attenDb); at diff = +knee/2 it reduces to
    // input.
    final t = (diff + kneeDb / 2) / kneeDb;
    out = inDb - attenDb * (1 - t * t);
  } else if (diff > kneeDb / 2) {
    out = inDb;
  } else {
    out = inDb - attenDb;
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
// Graph
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final AgateSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  final _inDb = ValueNotifier<double>(_meterMinDb);
  final _outDb = ValueNotifier<double>(_meterMinDb);
  final _grDb = ValueNotifier<double>(0);
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;
  double _inSmoothed = _meterMinDb;
  double _outSmoothed = _meterMinDb;

  @override
  void initState() {
    super.initState();
    _preSub = widget.player.stream
        .tap(AudioEffect.agate, side: TapSide.pre)
        .listen((pcm) {
      if (!mounted) return;
      _inSmoothed = _peakDb(pcm, _inSmoothed);
      _inDb.value = _inSmoothed;
      _grDb.value = (_inSmoothed - _outSmoothed).clamp(0.0, _grMaxDb);
    });
    _postSub = widget.player.stream
        .tap(AudioEffect.agate, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      _outSmoothed = _peakDb(pcm, _outSmoothed);
      _outDb.value = _outSmoothed;
      _grDb.value = (_inSmoothed - _outSmoothed).clamp(0.0, _grMaxDb);
    });
  }

  @override
  void dispose() {
    _preSub?.cancel();
    _postSub?.cancel();
    _inDb.dispose();
    _outDb.dispose();
    _grDb.dispose();
    super.dispose();
  }

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
                painter: _GatePainter(
                  settings: widget.settings,
                  inDb: _inDb,
                  outDb: _outDb,
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

class _GatePainter extends CustomPainter {
  final AgateSettings settings;
  final ValueListenable<double> inDb;
  final ValueListenable<double> outDb;

  _GatePainter({
    required this.settings,
    required this.inDb,
    required this.outDb,
  }) : super(repaint: Listenable.merge([inDb, outDb]));

  // Two-tier grid: major (labeled, brighter) every 12 dB, minor
  // (un-labeled, dimmer) every 6 dB between them. See acompressor's
  // window for the full rationale; the gate just reuses the pattern.
  static const _gridDbMajor = [-60, -48, -36, -24, -12, 0];
  static const _gridDbMinor = [-54, -42, -30, -18, -6];

  double get _thresholdDb => _ampToDb(settings.threshold);
  double get _makeupDb => _ampToDb(settings.makeup);
  double get _kneeDb => _ampToDb(settings.knee.clamp(1.0, 8.0));
  // `range` is the linear amplitude floor below threshold. Convert to
  // attenuation depth in dB: range = 0.06125 ≈ -24 dB attenuation.
  double get _attenDb => -_ampToDb(settings.range.clamp(0.0001, 1.0));

  double _y(double db, Size size) => _yOfDb(db, size);
  double _x(double db, Size size) => _xOfDb(db, size);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);
    final plot = PlotChrome.plotRect(size);

    // Two-tier grid: minor first (so majors paint over), brighter
    // major above so the labeled lines pop visibly.
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

    // y=x reference.
    canvas.drawLine(
      Offset(_x(_dbFloor, size), _y(_dbFloor, size)),
      Offset(_x(_dbCeil, size), _y(_dbCeil, size)),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    // Sub-threshold fill — left of threshold gets attenuated by the
    // gate, so wash that zone in faint red so the user reads the
    // "kill zone" at a glance.
    final tx = _x(_thresholdDb, size);
    canvas.drawRect(
      Rect.fromLTRB(plot.left, plot.top, tx, plot.bottom),
      Paint()..color = ConsoleSkin.meterRed.withValues(alpha: 0.08),
    );
    // Threshold marker, clipped to the plot rect.
    canvas.drawLine(
      Offset(tx, plot.top),
      Offset(tx, plot.bottom),
      Paint()
        ..color = ConsoleSkin.accentDim
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    // Curve.
    final curve = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final inputDb = _dbFloor + t * (_dbCeil - _dbFloor);
      final outDb = _gateOutDb(
        inputDb,
        thresholdDb: _thresholdDb,
        attenDb: _attenDb,
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

    // Live ball — red when input is below threshold (signal is being
    // attenuated), accent-hot when above (gate open).
    final iDb = inDb.value;
    if (iDb > _meterMinDb + 0.5) {
      final oDb = outDb.value;
      final bx = _x(iDb, size);
      final by = _y(oDb, size);
      final ballColor =
          iDb < _thresholdDb ? ConsoleSkin.meterRed : ConsoleSkin.accentHot;
      canvas.drawCircle(
        Offset(bx, by),
        5,
        Paint()..color = ballColor,
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

    _drawAxisLabels(canvas, size);
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    // Labels in the gutters via PlotChrome — one per major gridline.
    for (final db in _gridDbMajor) {
      PlotChrome.drawXLabel(
          canvas, size, _x(db.toDouble(), size), '$db');
      PlotChrome.drawYLabelRight(
          canvas, size, _y(db.toDouble(), size), '$db');
    }
    // Threshold label stays inside the plot anchored to its marker.
    final tx = _x(_thresholdDb, size);
    _drawLabel(canvas, 'THR ${_thresholdDb.toStringAsFixed(0)}',
        Offset(tx + 4, 4), ConsoleSkin.accentDim);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
    ))
      ..pushStyle(ui.TextStyle(color: color, fontSize: ConsoleSkin.sizeTiny))
      ..addText(text);
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 64));
    canvas.drawParagraph(p, offset);
  }

  @override
  bool shouldRepaint(_GatePainter old) => old.settings != settings;
}

// ──────────────────────────────────────────────────────────────────────
// Controls — seven knobs.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final AgateSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AgateSettings next) {
    player.updateAudioEffects((b) => b.copyWith(agate: next));
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
            value: _ampToDb(settings.threshold),
            min: -60,
            max: 0,
            defaultValue: _ampToDb(AgateSettings.thresholdDefault.clamp(1e-6, 1.0)),
            onChanged: (db) => _apply(settings.copyWith(
              threshold: _dbToAmp(db).clamp(
                AgateSettings.thresholdMin,
                AgateSettings.thresholdMax,
              ),
            )),
            label: 'thr dB',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.range),
            min: -60,
            max: 0,
            defaultValue: _ampToDb(AgateSettings.rangeDefault.clamp(1e-6, 1.0)),
            onChanged: (db) => _apply(settings.copyWith(
              range: _dbToAmp(db).clamp(
                AgateSettings.rangeMin,
                AgateSettings.rangeMax,
              ),
            )),
            label: 'range',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.ratio,
            // Spec ratio caps at 9000:1 — useless on a knob. Clamp the
            // visual range to a musical 1..20:1 (typical gate window);
            // engine clamp covers the full spec.
            min: 1,
            max: 20,
            defaultValue: AgateSettings.ratioDefault,
            onChanged: (v) => _apply(settings.copyWith(
              ratio: v.clamp(AgateSettings.ratioMin, AgateSettings.ratioMax),
            )),
            label: 'ratio',
            format: (v) => '${v.toStringAsFixed(1)}:1',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.attack,
            min: 0.1,
            max: 200,
            defaultValue: AgateSettings.attackDefault,
            onChanged: (v) => _apply(settings.copyWith(
              attack:
                  v.clamp(AgateSettings.attackMin, AgateSettings.attackMax),
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
            defaultValue: AgateSettings.releaseDefault,
            onChanged: (v) => _apply(settings.copyWith(
              release:
                  v.clamp(AgateSettings.releaseMin, AgateSettings.releaseMax),
            )),
            label: 'rel ms',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.knee,
            min: AgateSettings.kneeMin,
            max: AgateSettings.kneeMax,
            defaultValue: AgateSettings.kneeDefault,
            onChanged: (v) => _apply(settings.copyWith(knee: v)),
            label: 'knee',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.makeup),
            min: 0,
            max: 36,
            defaultValue: _ampToDb(AgateSettings.makeupDefault),
            onChanged: (db) => _apply(settings.copyWith(
              makeup: _dbToAmp(db).clamp(
                AgateSettings.makeupMin,
                AgateSettings.makeupMax,
              ),
            )),
            label: 'makeup',
            format: (v) => '+${v.toStringAsFixed(1)}',
            size: 70,
          ),
        ],
      ),
    );
  }
}
