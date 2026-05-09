import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_close_x.dart';
import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_spectrum_curve.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `mcompand` (multi-band compander).
/// Same per-band semantics as `acompressor` (threshold, ratio, attack,
/// release, knee, makeup) plus a per-band crossover frequency. A
/// frequency strip at the top exposes every band as a clickable
/// segment; the selected band gets the full knee-plot + knob editor.
///
/// Bands are read / written through the lib-side
/// [McompandBandsX.bands] typed extension — the lavfi `args` string
/// grammar lives in a single place
/// (`lib/src/types/settings/extensions/mcompand_bands.dart`).
///
/// Reference: FabFilter Pro-MB band selection, iZotope Ozone
/// Dynamics, Waves C6.
class McompandWindow extends StatefulWidget {
  final VoidCallback onClose;
  const McompandWindow({super.key, required this.onClose});

  @override
  State<McompandWindow> createState() => _McompandWindowState();
}

class _McompandWindowState extends State<McompandWindow> {
  /// Index of the band the user is currently editing. Lives on the
  /// outer state so the graph (band strip + knee plot) and the
  /// controls (knob row) read the same value.
  int _selected = 0;

  void _writeBack(Player p, McompandSettings s, List<McompandBand> bands) {
    p.updateAudioEffects(
      (b) => b.copyWith(mcompand: s.withBands(bands)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).mcompand;
        final bands = s.bands;
        // Clamp selection — bands removed externally must not blow up.
        final int sel = bands.isEmpty
            ? 0
            : _selected.clamp(0, bands.length - 1);
        return ProPluginWindow(
          filterName: 'mcompand',
          onClose: widget.onClose,
          graph: _Graph(
            player: p,
            bands: bands,
            selectedIdx: bands.isEmpty ? null : sel,
            onSelect: (i) => setState(() => _selected = i),
          ),
          controls: _Controls(
            bands: bands,
            selectedIdx: bands.isEmpty ? null : sel,
            onUpdate: (next) => _writeBack(p, s, next),
            onAddBand: () {
              final next = [...bands, _defaultBand(bands)];
              _writeBack(p, s, next);
              setState(() => _selected = next.length - 1);
            },
            onRemoveBand: () {
              if (bands.isEmpty) return;
              final next = [...bands]..removeAt(sel);
              _writeBack(p, s, next);
              setState(() => _selected = math.max(0, sel - 1));
            },
          ),
        );
      },
    );
  }
}

McompandBand _defaultBand(List<McompandBand> existing) {
  // Place the new band's crossover at twice the current top crossover
  // (or 1 kHz if this is the first band) so successive Add Band clicks
  // carve out sensible octave-wide bands by default.
  final topHz = existing.isEmpty
      ? 1000.0
      : existing.map((b) => b.crossoverHz).reduce(math.max);
  return McompandBand(
    thresholdDb: -24,
    ratio: 2,
    attackSeconds: 0.005,
    releaseSeconds: 0.1,
    kneeDb: 6,
    makeupDb: 0,
    crossoverHz: math.min(20000.0, topHz * 2),
  );
}

// ──────────────────────────────────────────────────────────────────────
// Graph — band strip on top, knee plot for the selected band below.
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatelessWidget {
  final Player player;
  final List<McompandBand> bands;
  final int? selectedIdx;
  final ValueChanged<int> onSelect;

  const _Graph({
    required this.player,
    required this.bands,
    required this.selectedIdx,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: _BandStrip(
              player: player,
              bands: bands,
              selectedIdx: selectedIdx,
              onSelect: onSelect,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bands.isEmpty || selectedIdx == null
                ? const Center(
                    child: AtomLabel(
                      'no bands — click ADD BAND below',
                      fontSize: ConsoleSkin.sizeTiny,
                      color: ConsoleSkin.fgFaint,
                      mono: true,
                    ),
                  )
                : RepaintBoundary(
                    child: CustomPaint(
                      painter: _KneePainter(band: bands[selectedIdx!]),
                      size: Size.infinite,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

const double _fLow = 20;
const double _fHigh = 20000;

double _xOfHz(double hz, double width) {
  final t = (math.log(hz.clamp(_fLow, _fHigh) / _fLow) /
          math.log(_fHigh / _fLow))
      .clamp(0.0, 1.0);
  return width * t;
}

class _BandStrip extends StatefulWidget {
  final Player player;
  final List<McompandBand> bands;
  final int? selectedIdx;
  final ValueChanged<int> onSelect;

  const _BandStrip({
    required this.player,
    required this.bands,
    required this.selectedIdx,
    required this.onSelect,
  });

  @override
  State<_BandStrip> createState() => _BandStripState();
}

class _BandStripState extends State<_BandStrip> {
  late final BandProcessor _preProc;
  late final BandProcessor _postProc;
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;
  StreamSubscription<SpectrumSettings>? _cfgSub;

  final _postBands = ValueNotifier<Float32List?>(null);
  final _preBands = ValueNotifier<Float32List?>(null);
  // Smoothed per-band GR proxy (dB), one entry per current band.
  // Sized lazily once we know the band count.
  List<double> _bandGrDb = const <double>[];

  @override
  void initState() {
    super.initState();
    _preProc = BandProcessor(widget.player.spectrumSettings);
    _postProc = BandProcessor(widget.player.spectrumSettings);
    _cfgSub = widget.player.stream.spectrum.listen((s) {
      _preProc.setSettings(s);
      _postProc.setSettings(s);
    });
    _preSub = widget.player.stream
        .tap(AudioEffect.mcompand, side: TapSide.pre)
        .listen((pcm) {
      if (!mounted) return;
      final f = _preProc.process(pcm);
      if (f != null) {
        _preBands.value = f.bands;
        _recomputeBandGr();
      }
    });
    _postSub = widget.player.stream
        .tap(AudioEffect.mcompand, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      final f = _postProc.process(pcm);
      if (f != null) {
        _postBands.value = f.bands;
        _recomputeBandGr();
      }
    });
  }

  /// Per-band GR proxy: average pre-vs-post spectrum magnitude over the
  /// band's frequency range. Not the true comp gain reduction (mcompand
  /// doesn't surface per-band GR through mpv) but visually correlates
  /// with how much each band is being squeezed.
  // TODO(backend): replace with a real per-band GR if mpv ever exposes
  // per-band reduction values for mcompand.
  void _recomputeBandGr() {
    final pre = _preBands.value;
    final post = _postBands.value;
    final bands = widget.bands;
    if (pre == null || post == null || bands.isEmpty) return;
    final n = pre.length;
    if (n == 0 || post.length != n) return;
    if (_bandGrDb.length != bands.length) {
      _bandGrDb = List<double>.filled(bands.length, 0);
    }
    final logRatio = math.log(_fHigh / _fLow);
    var prevHz = _fLow;
    for (var b = 0; b < bands.length; b++) {
      final hi = bands[b].crossoverHz.clamp(_fLow, _fHigh);
      // Map [prevHz, hi] → spectrum-band index range [iLo, iHi].
      final iLo = (math.log(prevHz / _fLow) / logRatio * (n - 1))
          .round()
          .clamp(0, n - 1);
      final iHi = (math.log(hi / _fLow) / logRatio * (n - 1))
          .round()
          .clamp(iLo, n - 1);
      var sumPre = 0.0;
      var sumPost = 0.0;
      for (var i = iLo; i <= iHi; i++) {
        sumPre += pre[i];
        sumPost += post[i];
      }
      final count = math.max(1, iHi - iLo + 1);
      final avgPre = sumPre / count;
      final avgPost = sumPost / count;
      // Convert linear magnitude delta to a dB-like proxy.
      final delta = (avgPre - avgPost).clamp(0.0, 1.0);
      // Smooth EMA — fast attack so the meter latches new GR, slow
      // release so a brief drop doesn't kill the readout.
      final prev = _bandGrDb[b];
      final target = delta * 24; // 0..24 dB readout scale
      final alpha = target > prev ? 0.6 : 0.08;
      _bandGrDb[b] = prev + alpha * (target - prev);
      prevHz = hi;
    }
  }

  @override
  void dispose() {
    _preSub?.cancel();
    _postSub?.cancel();
    _cfgSub?.cancel();
    _preBands.dispose();
    _postBands.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final width = c.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          if (widget.bands.isEmpty) return;
          final hz = math.exp(
            (d.localPosition.dx / width) * math.log(_fHigh / _fLow),
          ) *
              _fLow;
          var chosen = 0;
          for (var i = 0; i < widget.bands.length; i++) {
            if (hz <= widget.bands[i].crossoverHz) {
              chosen = i;
              break;
            }
            chosen = i;
          }
          widget.onSelect(chosen);
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _BandStripPainter(
              bands: widget.bands,
              selectedIdx: widget.selectedIdx,
              postBands: _postBands,
              bandGrDb: () => _bandGrDb,
            ),
            size: Size.infinite,
          ),
        ),
      );
    });
  }
}

class _BandStripPainter extends CustomPainter {
  final List<McompandBand> bands;
  final int? selectedIdx;
  final ValueListenable<Float32List?> postBands;
  final List<double> Function() bandGrDb;
  _BandStripPainter({
    required this.bands,
    required this.selectedIdx,
    required this.postBands,
    required this.bandGrDb,
  }) : super(repaint: postBands);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bg);

    final labelStyle = ui.TextStyle(
      color: ConsoleSkin.fgFaint,
      fontSize: ConsoleSkin.sizeTiny,
      fontFamily: ConsoleSkin.fontMono,
    );
    for (final hz in [100, 1000, 10000]) {
      final x = _xOfHz(hz.toDouble(), size.width);
      final label = hz >= 1000 ? '${hz ~/ 1000}k' : '$hz';
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontFamily: ConsoleSkin.fontMono,
        fontSize: ConsoleSkin.sizeTiny,
      ))
        ..pushStyle(labelStyle)
        ..addText(label);
      final p = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 32));
      canvas.drawParagraph(p, Offset(x + 2, size.height - 12));
    }

    if (bands.isEmpty) return;

    final stripTop = 4.0;
    final stripBottom = size.height - 14;
    final grRowH = 3.0; // per-band GR mini-meter sits at the strip top

    // Per-band coloured backgrounds + index labels, hue from
    // ConsoleSkin.bandPalette so each band reads as a distinct stripe.
    var xPrev = 0.0;
    for (var i = 0; i < bands.length; i++) {
      final xNext = _xOfHz(bands[i].crossoverHz, size.width);
      final selected = i == selectedIdx;
      final hue = ConsoleSkin.bandPalette[i % ConsoleSkin.bandPalette.length];
      canvas.drawRect(
        Rect.fromLTRB(xPrev + 1, stripTop, xNext - 1, stripBottom),
        Paint()
          ..color = selected
              ? hue.withValues(alpha: 0.55)
              : hue.withValues(alpha: 0.18),
      );

      // Per-band GR mini-meter — accent fill at the top, height
      // proportional to current per-band GR proxy (0..24 dB → 0..grRowH).
      final grList = bandGrDb();
      if (i < grList.length) {
        final gr = grList[i].clamp(0.0, 24.0);
        if (gr > 0.05) {
          final w = (xNext - 1) - (xPrev + 1);
          if (w > 0) {
            final filledW = w * (gr / 24.0);
            canvas.drawRect(
              Rect.fromLTWH(xPrev + 1, stripTop, filledW, grRowH),
              Paint()..color = hue,
            );
          }
        }
      }

      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontFamily: ConsoleSkin.fontMono,
        fontSize: ConsoleSkin.sizeTiny,
      ))
        ..pushStyle(ui.TextStyle(
          color: selected ? hue : hue.withValues(alpha: 0.7),
          fontSize: ConsoleSkin.sizeTiny,
        ))
        ..addText('${i + 1}');
      final p = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 32));
      final cx = (xPrev + xNext) / 2 - p.width / 2;
      canvas.drawParagraph(p, Offset(cx, stripTop + grRowH + 1));
      xPrev = xNext;
    }

    // Live spectrum overlay — clip per band so each segment uses its
    // own hue. Spectrum sits inside the full strip rect.
    final post = postBands.value;
    if (post != null && post.length >= 2) {
      final stripRect = Rect.fromLTRB(0, stripTop, size.width, stripBottom);
      var xPrevS = 0.0;
      for (var i = 0; i < bands.length; i++) {
        final xNext = _xOfHz(bands[i].crossoverHz, size.width);
        final clip = Rect.fromLTRB(xPrevS, stripTop, xNext, stripBottom);
        if (clip.width <= 0) {
          xPrevS = xNext;
          continue;
        }
        final hue =
            ConsoleSkin.bandPalette[i % ConsoleSkin.bandPalette.length];
        canvas.save();
        canvas.clipRect(clip);
        SpectrumCurve.paintOn(
          canvas,
          stripRect,
          post,
          color: hue.withValues(alpha: 0.9),
          fillUnder: true,
          fillAlpha: 0.35,
          strokeWidth: 1,
        );
        canvas.restore();
        xPrevS = xNext;
      }
    }

    // Crossover lines + Hz labels — line uses the band's own hue.
    for (var i = 0; i < bands.length; i++) {
      final x = _xOfHz(bands[i].crossoverHz, size.width);
      final hue = ConsoleSkin.bandPalette[i % ConsoleSkin.bandPalette.length];
      canvas.drawLine(
        Offset(x.floorToDouble() + 0.5, 2),
        Offset(x.floorToDouble() + 0.5, stripBottom),
        Paint()
          ..color = hue
          ..strokeWidth = 1
          ..isAntiAlias = true,
      );
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontFamily: ConsoleSkin.fontMono,
        fontSize: ConsoleSkin.sizeTiny,
      ))
        ..pushStyle(ui.TextStyle(
          color: ConsoleSkin.fgDim,
          fontSize: ConsoleSkin.sizeTiny,
        ))
        ..addText(bands[i].crossoverHz >= 1000
            ? '${(bands[i].crossoverHz / 1000).toStringAsFixed(1)}k'
            : bands[i].crossoverHz.toStringAsFixed(0));
      final p = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 36));
      canvas.drawParagraph(p, Offset(x + 3, 4));
    }
  }

  @override
  bool shouldRepaint(_BandStripPainter old) =>
      old.bands.length != bands.length ||
      old.selectedIdx != selectedIdx ||
      _diff(old.bands, bands);

  bool _diff(List<McompandBand> a, List<McompandBand> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].crossoverHz != b[i].crossoverHz) return true;
    }
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────
// Knee plot — same shape and math as `acompressor`, parameterised on
// the selected band.
// ──────────────────────────────────────────────────────────────────────

const double _dbFloor = -60;
const double _dbCeil = 0;
const List<int> _kneeGridMajor = [-60, -48, -36, -24, -12, 0];
const List<int> _kneeGridMinor = [-54, -42, -30, -18, -6];

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

class _KneePainter extends CustomPainter {
  final McompandBand band;
  _KneePainter({required this.band});

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);

    // Two-tier dB grid: minors first, majors on top.
    for (final db in _kneeGridMinor) {
      PlotChrome.drawVGrid(canvas, size, _xOfDb(db.toDouble(), size));
      PlotChrome.drawHGrid(canvas, size, _yOfDb(db.toDouble(), size));
    }
    for (final db in _kneeGridMajor) {
      PlotChrome.drawVGrid(
        canvas,
        size,
        _xOfDb(db.toDouble(), size),
        color: ConsoleSkin.fgFaint,
      );
      PlotChrome.drawHGrid(
        canvas,
        size,
        _yOfDb(db.toDouble(), size),
        color: ConsoleSkin.fgFaint,
      );
    }

    // Unity diagonal — what passes through unchanged.
    canvas.drawLine(
      Offset(_xOfDb(_dbFloor, size), _yOfDb(_dbFloor, size)),
      Offset(_xOfDb(_dbCeil, size), _yOfDb(_dbCeil, size)),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    // Threshold marker — vertical line, clipped to the plot rect.
    final tx = _xOfDb(band.thresholdDb, size);
    canvas.drawLine(
      Offset(tx, plot.top),
      Offset(tx, plot.bottom),
      Paint()
        ..color = ConsoleSkin.accentDim
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    final curve = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final inputDb = _dbFloor + t * (_dbCeil - _dbFloor);
      final outDb = _kneeOutDb(
        inputDb,
        thresholdDb: band.thresholdDb,
        ratio: band.ratio,
        kneeDb: band.kneeDb,
        makeupDb: band.makeupDb,
      );
      final x = _xOfDb(inputDb, size);
      final y = _yOfDb(outDb, size);
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

    // Axis labels — input dB along the bottom, output dB along the right.
    for (final db in _kneeGridMajor) {
      PlotChrome.drawXLabel(canvas, size, _xOfDb(db.toDouble(), size), '$db');
      PlotChrome.drawYLabelRight(
        canvas,
        size,
        _yOfDb(db.toDouble(), size),
        '$db',
        color: db == 0 ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint,
      );
    }
  }

  @override
  bool shouldRepaint(_KneePainter old) =>
      old.band.thresholdDb != band.thresholdDb ||
      old.band.ratio != band.ratio ||
      old.band.kneeDb != band.kneeDb ||
      old.band.makeupDb != band.makeupDb;
}

// ──────────────────────────────────────────────────────────────────────
// Controls — knob row scoped to the selected band.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final List<McompandBand> bands;
  final int? selectedIdx;
  final ValueChanged<List<McompandBand>> onUpdate;
  final VoidCallback onAddBand;
  final VoidCallback onRemoveBand;

  const _Controls({
    required this.bands,
    required this.selectedIdx,
    required this.onUpdate,
    required this.onAddBand,
    required this.onRemoveBand,
  });

  void _updateBand(McompandBand Function(McompandBand) f) {
    final i = selectedIdx;
    if (i == null) return;
    final next = [...bands];
    next[i] = f(next[i]);
    onUpdate(next);
  }

  double _tToHz(double t) =>
      _fLow * math.pow(_fHigh / _fLow, t.clamp(0.0, 1.0)).toDouble();
  double _hzToT(double hz) =>
      math.log(hz.clamp(_fLow, _fHigh) / _fLow) / math.log(_fHigh / _fLow);

  @override
  Widget build(BuildContext context) {
    final hasBand = selectedIdx != null;
    final band = hasBand ? bands[selectedIdx!] : _defaultBand(const []);
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AtomKnob(
                  value: band.thresholdDb,
                  min: -60,
                  max: 0,
                  defaultValue: -24,
                  enabled: hasBand,
                  onChanged: (v) =>
                      _updateBand((b) => b.copyWith(thresholdDb: v)),
                  label: 'thr dB',
                  format: (v) => v.toStringAsFixed(1),
                  size: 70,
                ),
                const SizedBox(width: 12),
                AtomKnob(
                  value: band.ratio,
                  min: 1,
                  max: 20,
                  defaultValue: 2,
                  enabled: hasBand,
                  onChanged: (v) => _updateBand((b) => b.copyWith(ratio: v)),
                  label: 'ratio',
                  format: (v) => '${v.toStringAsFixed(1)}:1',
                  size: 70,
                ),
                const SizedBox(width: 12),
                AtomKnob(
                  // mcompand stores attack/release in seconds; UI in ms.
                  value: band.attackSeconds * 1000,
                  min: 0.1,
                  max: 200,
                  defaultValue: 5,
                  enabled: hasBand,
                  onChanged: (v) =>
                      _updateBand((b) => b.copyWith(attackSeconds: v / 1000)),
                  label: 'atk ms',
                  format: (v) => v.toStringAsFixed(1),
                  size: 70,
                ),
                const SizedBox(width: 12),
                AtomKnob(
                  value: band.releaseSeconds * 1000,
                  min: 1,
                  max: 2000,
                  defaultValue: 100,
                  enabled: hasBand,
                  onChanged: (v) =>
                      _updateBand((b) => b.copyWith(releaseSeconds: v / 1000)),
                  label: 'rel ms',
                  format: (v) => v.toStringAsFixed(0),
                  size: 70,
                ),
                const SizedBox(width: 12),
                AtomKnob(
                  value: band.kneeDb,
                  min: 0,
                  max: 24,
                  defaultValue: 6,
                  enabled: hasBand,
                  onChanged: (v) =>
                      _updateBand((b) => b.copyWith(kneeDb: v)),
                  label: 'knee dB',
                  format: (v) => v.toStringAsFixed(1),
                  size: 70,
                ),
                const SizedBox(width: 12),
                AtomKnob(
                  value: band.makeupDb,
                  min: -12,
                  max: 24,
                  defaultValue: 0,
                  enabled: hasBand,
                  onChanged: (v) =>
                      _updateBand((b) => b.copyWith(makeupDb: v)),
                  label: 'makeup',
                  format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
                  size: 70,
                ),
                const SizedBox(width: 12),
                AtomKnob(
                  value: _hzToT(band.crossoverHz),
                  min: 0,
                  max: 1,
                  defaultValue: _hzToT(1000),
                  enabled: hasBand,
                  onChanged: (t) => _updateBand(
                      (b) => b.copyWith(crossoverHz: _tToHz(t))),
                  label: 'xover',
                  format: (t) {
                    final hz = _tToHz(t);
                    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}k';
                    return hz.toStringAsFixed(0);
                  },
                  size: 70,
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAddBand,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: AtomLabel(
                    '+ ADD BAND',
                    fontSize: ConsoleSkin.sizeTiny,
                    color: ConsoleSkin.accent,
                    mono: true,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (hasBand)
                AtomCloseX(onTap: onRemoveBand),
            ],
          ),
        ],
      ),
    );
  }
}
