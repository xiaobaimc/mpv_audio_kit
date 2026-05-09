import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import '../skin/paint_helpers.dart';

/// Vertical level meter — feed it raw amplitude (`0..1`) or dB samples
/// and it applies pro-style PPM ballistics + a peak-hold marker. The
/// caller pumps a `ValueListenable<double>` of incoming peaks (per
/// audio frame); the meter does its own envelope smoothing and
/// peak-hold timing on a Ticker, so the painter repaints in lockstep
/// with the engine without rebuilding the widget tree.
///
/// **Ballistics** follow EBU/IEC PPM Type II:
///   * attack  ≈ 5 ms   — meter rises almost instantly with the signal
///   * release ≈ 1.7 s  — slow fall so peaks remain readable
///   * peak-hold marker latches the last 1.5 s maximum, then falls
///     at ~12 dB/s (Pro-L 2 / Insight convention)
///
/// **Color zones** (top-down): red above [redDb], amber between
/// [amberDb] and [redDb], green below [amberDb]. Defaults are
/// EBU R 128 alignment-friendly: green ≤ -18 dB, amber -18..-6 dB,
/// red ≥ -6 dB. For limiters, pass `redDb = settings.limit`.
///
/// **Direction:** [Direction.upFromBottom] (default — peak meter,
/// fills upward) or [Direction.downFromTop] (GR meter, fills
/// downward; canonical convention since SSL G-series).
enum MeterDirection { upFromBottom, downFromTop }

class AtomLevelMeter extends StatefulWidget {
  /// Live amplitude source. When [ampDb] is true the listenable carries
  /// dB values directly (e.g. `-12.4`); otherwise it carries linear
  /// amplitude in `[0, 1]` (e.g. `0.5` → -6 dB).
  final ValueListenable<double> source;
  final bool sourceInDb;
  final double minDb;
  final double maxDb;
  final double amberDb;
  final double redDb;
  final MeterDirection direction;
  /// Show the peak-hold marker (a single hairline at the latched max).
  final bool peakHold;
  /// Show a numeric "max GR / max peak" readout above the meter.
  final bool numericReadout;
  /// Width of the painted bar; total widget width is this + 2 px
  /// breathing on each side.
  final double width;
  /// Optional reference label drawn above (e.g. "GR", "TP", "L").
  final String? label;

  const AtomLevelMeter({
    super.key,
    required this.source,
    this.sourceInDb = false,
    this.minDb = -60,
    this.maxDb = 0,
    this.amberDb = -18,
    this.redDb = -6,
    this.direction = MeterDirection.upFromBottom,
    this.peakHold = true,
    this.numericReadout = false,
    this.width = 14,
    this.label,
  });

  @override
  State<AtomLevelMeter> createState() => _AtomLevelMeterState();
}

class _AtomLevelMeterState extends State<AtomLevelMeter>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Current displayed level (dB). EMA-smoothed via PPM ballistics.
  double _displayDb = -120;

  /// Peak-hold marker (dB). Latches the highest reading for
  /// [_holdMs] ms, then falls at [_fallDbPerSec] dB/s.
  double _holdDb = -120;
  Duration _holdSetAt = Duration.zero;

  /// Highest observed value since the last reset — drives the numeric
  /// readout above the meter.
  double _maxObservedDb = -120;

  // PPM-II ballistics. Tau values are converted into the per-frame
  // alpha = 1 - exp(-dt/tau).
  static const double _tauAttackS = 0.005;
  static const double _tauReleaseS = 1.7;
  static const int _holdMs = 1500;
  static const double _fallDbPerSec = 12;

  double _ampToDb(double amp) {
    final a = amp.abs();
    if (a <= 1e-9) return -120;
    return 20 * (math.log(a) / math.ln10);
  }

  @override
  void initState() {
    super.initState();
    widget.source.addListener(_onSample);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(AtomLevelMeter old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      old.source.removeListener(_onSample);
      widget.source.addListener(_onSample);
    }
  }

  @override
  void dispose() {
    widget.source.removeListener(_onSample);
    _ticker.dispose();
    super.dispose();
  }

  /// New input sample: keep raw value latched. The actual envelope
  /// progression happens in [_onTick] so the time constants are
  /// frame-rate-independent (engine taps at ~30 Hz, ticker at ~60 Hz).
  double _pendingDb = -120;

  void _onSample() {
    final v = widget.source.value;
    final db = widget.sourceInDb ? v : _ampToDb(v);
    if (db > _pendingDb) _pendingDb = db; // peak-detect within tick
  }

  void _onTick(Duration elapsed) {
    final dtMs = (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    if (dtMs <= 0) return;
    final dtS = dtMs / 1000.0;

    // Pull the latched peak; reset for next tick window.
    final inputDb = _pendingDb;
    _pendingDb = -120;

    // PPM envelope: fast attack, slow release. Asymmetric tau so the
    // meter follows transients to the top but bleeds back down slowly.
    final tau = inputDb > _displayDb ? _tauAttackS : _tauReleaseS;
    final alpha = 1 - math.exp(-dtS / tau);
    _displayDb = _displayDb + alpha * (inputDb - _displayDb);

    // Peak-hold: set on any new max; latch for [_holdMs] ms, then
    // fall at [_fallDbPerSec] dB/s.
    if (_displayDb > _holdDb) {
      _holdDb = _displayDb;
      _holdSetAt = elapsed;
    } else {
      final heldMs = (elapsed - _holdSetAt).inMilliseconds;
      if (heldMs > _holdMs) {
        _holdDb -= _fallDbPerSec * dtS;
        if (_holdDb < _displayDb) _holdDb = _displayDb;
      }
    }

    if (_displayDb > _maxObservedDb) _maxObservedDb = _displayDb;

    setState(() {});
  }

  void resetMax() => setState(() => _maxObservedDb = -120);

  @override
  Widget build(BuildContext context) {
    final reading = _displayDb.clamp(widget.minDb, widget.maxDb);
    final hold = _holdDb.clamp(widget.minDb, widget.maxDb);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.numericReadout)
          GestureDetector(
            onTap: resetMax,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: widget.width + 18,
              child: Text(
                _maxObservedDb <= widget.minDb
                    ? '—'
                    : _maxObservedDb.toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ConsoleSkin.sizeTiny,
                  color: _maxObservedDb >= widget.redDb
                      ? ConsoleSkin.meterRed
                      : ConsoleSkin.fg,
                  fontFamily: ConsoleSkin.fontMono,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        Expanded(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MeterPainter(
                db: reading,
                holdDb: widget.peakHold ? hold : null,
                minDb: widget.minDb,
                maxDb: widget.maxDb,
                amberDb: widget.amberDb,
                redDb: widget.redDb,
                direction: widget.direction,
              ),
              size: Size(widget.width, double.infinity),
            ),
          ),
        ),
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.label!,
              style: const TextStyle(
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                fontFamily: ConsoleSkin.fontMono,
              ),
            ),
          ),
      ],
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double db;
  final double? holdDb;
  final double minDb;
  final double maxDb;
  final double amberDb;
  final double redDb;
  final MeterDirection direction;

  _MeterPainter({
    required this.db,
    required this.holdDb,
    required this.minDb,
    required this.maxDb,
    required this.amberDb,
    required this.redDb,
    required this.direction,
  });

  /// Map [v] ∈ [minDb, maxDb] to a pixel Y. For [upFromBottom], minDb
  /// → bottom and maxDb → top; for [downFromTop] the meter still
  /// paints from the same pixel space but the fill grows from the
  /// top edge instead of from the bottom.
  double _yOfDb(double v, double height) {
    final t = ((v - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    return height * (1 - t);
  }

  Color _zoneColor(double v) {
    if (v >= redDb) return ConsoleSkin.meterRed;
    if (v >= amberDb) return ConsoleSkin.meterAmber;
    return ConsoleSkin.meterGreen;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background well + hairline outline.
    final rect = Offset.zero & size;
    box(canvas, rect, fill: ConsoleSkin.bg, border: ConsoleSkin.hairline);
    final inner = rect.deflate(1);
    if (inner.width <= 0 || inner.height <= 0) return;

    // Compose a 3-stop gradient that covers the colour zones based on
    // their dB locations on the strip. This way the bar's appearance
    // is uniform regardless of the active reading: the visible "lit"
    // segment just shows whichever portion of the gradient it covers.
    final amberY = _yOfDb(amberDb, inner.height);
    final redY = _yOfDb(redDb, inner.height);
    final stops = [
      0.0, // top
      (redY / inner.height).clamp(0.0, 1.0),
      ((redY + 1) / inner.height).clamp(0.0, 1.0),
      (amberY / inner.height).clamp(0.0, 1.0),
      ((amberY + 1) / inner.height).clamp(0.0, 1.0),
      1.0, // bottom
    ];
    final colors = [
      ConsoleSkin.meterRed,
      ConsoleSkin.meterRed,
      ConsoleSkin.meterAmber,
      ConsoleSkin.meterAmber,
      ConsoleSkin.meterGreen,
      ConsoleSkin.meterGreen,
    ];
    // Sort stops monotonically (in case redY > amberY because of an
    // exotic param combo).
    final paired = List.generate(stops.length, (i) => (stops[i], colors[i]));
    paired.sort((a, b) => a.$1.compareTo(b.$1));
    final sortedStops = paired.map((p) => p.$1).toList();
    final sortedColors = paired.map((p) => p.$2).toList();

    final litTopY = direction == MeterDirection.upFromBottom
        ? _yOfDb(db, inner.height)
        : inner.top;
    final litBottomY = direction == MeterDirection.upFromBottom
        ? inner.height
        : _yOfDb(db, inner.height);
    final litRect = Rect.fromLTRB(
      inner.left,
      inner.top + litTopY,
      inner.right,
      inner.top + litBottomY,
    );
    if (litRect.height > 0) {
      canvas.drawRect(
        litRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: sortedColors,
            stops: sortedStops,
          ).createShader(inner),
      );
    }

    // Peak-hold marker — single 1 px horizontal stroke at hold dB.
    if (holdDb != null) {
      final hy = _yOfDb(holdDb!, inner.height) + inner.top;
      canvas.drawLine(
        Offset(inner.left, hy.floorToDouble() + 0.5),
        Offset(inner.right, hy.floorToDouble() + 0.5),
        Paint()
          ..color = _zoneColor(holdDb!)
          ..strokeWidth = 1
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.db != db ||
      old.holdDb != holdDb ||
      old.minDb != minDb ||
      old.maxDb != maxDb ||
      old.amberDb != amberDb ||
      old.redDb != redDb ||
      old.direction != direction;
}
