import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../atoms/atom_dropdown.dart';
import '../../atoms/atom_knob.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_spectrum_curve.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

// ──────────────────────────────────────────────────────────────────────
// Pro-style window for the lavfi `anequalizer` filter — multi-band
// parametric EQ with a draggable response curve.
//
// Typed model lives lib-side as [AnequalizerBand] / [AnequalizerBandsX]
// (`s.bands`, `s.withBands(...)`). The mpv lavfi `[...]` escape that
// used to live here is now applied automatically by the codegen's
// `toFilterString()`. This file is purely the UI layer.
// ──────────────────────────────────────────────────────────────────────

const double _fMin = 20;
const double _fMax = 20000;
const double _dbMin = -24;
const double _dbMax = 24;

// ──────────────────────────────────────────────────────────────────────
// Window
// ──────────────────────────────────────────────────────────────────────

class AnequalizerWindow extends StatefulWidget {
  final VoidCallback onClose;
  const AnequalizerWindow({super.key, required this.onClose});

  @override
  State<AnequalizerWindow> createState() => _AnequalizerWindowState();
}

class _AnequalizerWindowState extends State<AnequalizerWindow> {
  /// Index of the band currently selected for fine-grained editing in
  /// the controls area, or null when no band is selected.
  int? _selected;

  void _writeBack(Player p, AnequalizerSettings s, List<AnequalizerBand> bands) {
    p.updateAudioEffects(
      (b) => b.copyWith(anequalizer: s.withBands(bands)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.anequalizer;
        final bands = s.bands;

        // Clamp selection if a band was removed externally.
        final sel = (_selected != null && _selected! < bands.length)
            ? _selected
            : null;

        return ProPluginWindow(
          filterName: 'anequalizer',
          onClose: widget.onClose,
          graph: _Graph(
            settings: s,
            bands: bands,
            selectedIdx: sel,
            onSelect: (i) => setState(() => _selected = i),
            onUpdate: (next) => _writeBack(p, s, next),
            player: p,
          ),
          controls: _Controls(
            settings: s,
            bands: bands,
            selectedIdx: sel,
            onUpdate: (next) => _writeBack(p, s, next),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Graph: live FFT spectrum + summed response curve + N draggable
// markers. Click empty area = add band. Click marker = select. Drag
// marker = move it. Right-click marker = remove.
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final AnequalizerSettings settings;
  final List<AnequalizerBand> bands;
  final int? selectedIdx;
  final ValueChanged<int?> onSelect;
  final ValueChanged<List<AnequalizerBand>> onUpdate;
  final Player player;

  const _Graph({
    required this.settings,
    required this.bands,
    required this.selectedIdx,
    required this.onSelect,
    required this.onUpdate,
    required this.player,
  });

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  // Pre / post FFT bands derived from the per-filter PCM tap.
  // [BandProcessor] runs the same FFT / windowing / smoothing the
  // library uses for the global visualizer. ValueNotifier-driven
  // repaints to keep the (heavy) widget tree out of the 60 Hz path.
  final _preBands = ValueNotifier<Float32List?>(null);
  final _postBands = ValueNotifier<Float32List?>(null);
  SpectrumPeakHold? _preHold;
  SpectrumPeakHold? _postHold;
  late final BandProcessor _preProc;
  late final BandProcessor _postProc;
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;
  StreamSubscription<SpectrumSettings>? _cfgSub;

  // Index of the band the cursor is currently dragging, if any.
  int? _dragIdx;
  // Index of the band the cursor is hovering, if any. Drives the
  // marker grow + ghost curve preview so users can read what a band
  // does without having to click first.
  int? _hoverIdx;

  // Floating tooltip shown next to a marker while the user drags it.
  OverlayEntry? _tooltipEntry;
  final GlobalKey _plotKey = GlobalKey();
  Size _plotSize = Size.zero;

  Duration get _now => Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch);

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
        .tap(AudioEffect.anequalizer, side: TapSide.pre)
        .listen((pcm) {
      if (!mounted) return;
      final f = _preProc.process(pcm);
      if (f != null) {
        _preHold ??= SpectrumPeakHold(length: f.bands.length);
        _preHold!.update(f.bands, _now);
        _preBands.value = f.bands;
      }
    });
    _postSub = widget.player.stream
        .tap(AudioEffect.anequalizer, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      final f = _postProc.process(pcm);
      if (f != null) {
        _postHold ??= SpectrumPeakHold(length: f.bands.length);
        _postHold!.update(f.bands, _now);
        _postBands.value = f.bands;
      }
    });
  }

  @override
  void dispose() {
    _hideTooltip();
    _preSub?.cancel();
    _postSub?.cancel();
    _cfgSub?.cancel();
    _preBands.dispose();
    _postBands.dispose();
    super.dispose();
  }

  // ── Tooltip ─────────────────────────────────────────────────────
  //
  // Floating chip showing live `f / G / Q` for the band under the
  // cursor while it is being dragged. Cribbed from AtomKnob's overlay
  // pattern: insert into the root overlay, mark needs build on every
  // value change, remove on drag end.

  void _showTooltip() {
    if (_tooltipEntry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _tooltipEntry = OverlayEntry(builder: _buildTooltip);
    overlay.insert(_tooltipEntry!);
  }

  void _refreshTooltip() => _tooltipEntry?.markNeedsBuild();

  void _hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  Widget _buildTooltip(BuildContext _) {
    final i = _dragIdx;
    if (i == null || i >= widget.bands.length) {
      return const SizedBox.shrink();
    }
    final box = _plotKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return const SizedBox.shrink();
    final origin = box.localToGlobal(Offset.zero);
    final b = widget.bands[i];
    final mx = _xOfStatic(b.frequency, _plotSize);
    final my = _yOfStatic(b.gain, _plotSize);
    final hzText = b.frequency >= 1000
        ? '${(b.frequency / 1000).toStringAsFixed(1)}k'
        : b.frequency.toStringAsFixed(0);
    final text =
        '$hzText  ${b.gain >= 0 ? '+' : ''}${b.gain.toStringAsFixed(1)}dB  Q${b.q.toStringAsFixed(2)}';
    return Positioned(
      left: origin.dx + mx - 70,
      top: origin.dy + my - 22,
      width: 140,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ConsoleSkin.bg,
              border: Border.all(
                color: ConsoleSkin.accentDim,
                width: ConsoleSkin.hairlinePx,
              ),
              borderRadius: BorderRadius.circular(ConsoleSkin.radius),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fg,
                fontFamily: ConsoleSkin.fontMono,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Inverse of [_xOfStatic] / [_yOfStatic] — operates in plot-rect
  // coordinates so the gutters at right / bottom don't shift the
  // mapping.
  double _freqAt(double dx, Size size) {
    final plot = PlotChrome.plotRect(size);
    if (plot.width <= 0) return _fMin;
    final t = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return _fMin * math.pow(_fMax / _fMin, t).toDouble();
  }

  double _gainAt(double dy, Size size) {
    final plot = PlotChrome.plotRect(size);
    if (plot.height <= 0) return 0;
    final t = (1 - ((dy - plot.top) / plot.height).clamp(0.0, 1.0));
    return _dbMin + t * (_dbMax - _dbMin);
  }

  /// Hit-test a marker. Returns the index of the band whose marker is
  /// within [tolerance] pixels of [pos], or null.
  int? _hitTest(Offset pos, Size size, {double tolerance = 14}) {
    var bestI = -1;
    var bestD = double.infinity;
    for (var i = 0; i < widget.bands.length; i++) {
      final b = widget.bands[i];
      final mx = _xOfStatic(b.frequency, size);
      final my = _yOfStatic(b.gain, size);
      final d = (Offset(mx, my) - pos).distance;
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    return bestD <= tolerance && bestI >= 0 ? bestI : null;
  }

  /// Add a new band at the cursor position. Selected after creation
  /// so the controls scoping snaps to it. Returns the new index.
  int _addBandAt(Offset pos, Size size) {
    final f = _freqAt(pos.dx, size);
    final g = _gainAt(pos.dy, size);
    // Default bandwidth: enough for a moderate Q ≈ 1.4 (musically broad).
    final w = (f / 1.4).clamp(20.0, 18000.0);
    final next = [
      ...widget.bands,
      AnequalizerBand(frequency: f, bandwidth: w, gain: g),
    ];
    final newIdx = next.length - 1;
    widget.onSelect(newIdx);
    widget.onUpdate(next);
    return newIdx;
  }

  void _onTapDown(TapDownDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit != null) {
      widget.onSelect(hit);
    } else {
      // Single click on empty area → ADD a new band at that point.
      // (onPanStart only fires after the cursor moves enough to count
      // as a drag; without this branch, a plain click does nothing.)
      _addBandAt(d.localPosition, size);
    }
  }

  void _onPanStart(DragStartDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit != null) {
      // Drag from existing marker.
      _dragIdx = hit;
      widget.onSelect(hit);
    } else {
      // Drag from empty area → create + drag.
      _dragIdx = _addBandAt(d.localPosition, size);
    }
    _showTooltip();
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final i = _dragIdx;
    if (i == null || i >= widget.bands.length) return;
    final f = _freqAt(d.localPosition.dx, size);
    final g = _gainAt(d.localPosition.dy, size);
    final next = [...widget.bands];
    next[i] = next[i].copyWith(
      frequency: f.clamp(_fMin, _fMax),
      gain: g.clamp(_dbMin, _dbMax),
    );
    widget.onUpdate(next);
    _refreshTooltip();
  }

  void _onPanEnd(DragEndDetails _) {
    _dragIdx = null;
    _hideTooltip();
  }

  void _onSecondaryTapDown(TapDownDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit == null) return;
    final next = [...widget.bands]..removeAt(hit);
    widget.onUpdate(next);
    widget.onSelect(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        _plotSize = size;
        return MouseRegion(
          cursor: _hoverIdx != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.precise,
          onHover: (e) {
            final hit = _hitTest(e.localPosition, size);
            if (hit != _hoverIdx) setState(() => _hoverIdx = hit);
          },
          onExit: (_) {
            if (_hoverIdx != null) setState(() => _hoverIdx = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPanStart(d, size),
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: _onPanEnd,
            onTapDown: (d) => _onTapDown(d, size),
            onSecondaryTapDown: (d) => _onSecondaryTapDown(d, size),
            child: RepaintBoundary(
              key: _plotKey,
              child: CustomPaint(
                painter: _AnEqGraphPainter(
                  bands: widget.bands,
                  selectedIdx: widget.selectedIdx,
                  hoveredIdx: _hoverIdx,
                  preBands: _preBands,
                  postBands: _postBands,
                  preHold: _preHold,
                  postHold: _postHold,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }
}

double _xOfStatic(double f, Size size) {
  final plot = PlotChrome.plotRect(size);
  final t = (math.log(f.clamp(_fMin, _fMax) / _fMin) /
          math.log(_fMax / _fMin))
      .clamp(0.0, 1.0);
  return plot.left + plot.width * t;
}

double _yOfStatic(double db, Size size) {
  final plot = PlotChrome.plotRect(size);
  final t = ((db.clamp(_dbMin, _dbMax) - _dbMin) / (_dbMax - _dbMin))
      .clamp(0.0, 1.0);
  return plot.top + plot.height * (1 - t);
}

class _AnEqGraphPainter extends CustomPainter {
  final List<AnequalizerBand> bands;
  final int? selectedIdx;
  final int? hoveredIdx;
  final ValueListenable<Float32List?> preBands;
  final ValueListenable<Float32List?> postBands;
  final SpectrumPeakHold? preHold;
  final SpectrumPeakHold? postHold;

  static const _dbGridMajor = [-18, -12, -6, 0, 6, 12, 18];
  static const _dbGridMinor = [-15, -9, -3, 3, 9, 15];

  _AnEqGraphPainter({
    required this.bands,
    required this.selectedIdx,
    required this.hoveredIdx,
    required this.preBands,
    required this.postBands,
    required this.preHold,
    required this.postHold,
  }) : super(repaint: Listenable.merge([preBands, postBands]));

  Color _bandColor(int i) =>
      ConsoleSkin.bandPalette[i % ConsoleSkin.bandPalette.length];

  /// Bell response in dB at frequency [f] for a band centred at
  /// [b.frequency] with bandwidth [b.bandwidth] (Hz). Approximation —
  /// Q-octave conversion via asinh.
  double _bandDb(AnequalizerBand b, double f) {
    if (b.frequency <= 0 || b.gain == 0 || b.bandwidth <= 0) return 0;
    final q = (b.frequency / b.bandwidth).clamp(0.05, 100.0);
    final x = 1.0 / (2.0 * q);
    final asinh = math.log(x + math.sqrt(x * x + 1));
    final halfBw = (2.0 / math.log(2)) * asinh / 2.0;
    if (halfBw <= 0) return 0;
    final octs = math.log(f / b.frequency) / math.log(2);
    final w = octs / halfBw;
    return b.gain * math.exp(-w * w);
  }

  double _summedDb(double f) {
    var sum = 0.0;
    for (final b in bands) {
      sum += _bandDb(b, f);
    }
    return sum;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);

    // Two-tier grid: minors first, majors on top.
    for (final f in PlotChrome.freqMinor) {
      PlotChrome.drawVGrid(canvas, size, _xOfStatic(f, size));
    }
    for (final db in _dbGridMinor) {
      PlotChrome.drawHGrid(canvas, size, _yOfStatic(db.toDouble(), size));
    }
    for (final f in PlotChrome.freqMajor) {
      PlotChrome.drawVGrid(canvas, size, _xOfStatic(f, size),
          color: ConsoleSkin.fgFaint);
    }
    for (final db in _dbGridMajor) {
      if (db == 0) continue;
      PlotChrome.drawHGrid(canvas, size, _yOfStatic(db.toDouble(), size));
    }
    PlotChrome.drawZeroH(canvas, size, _yOfStatic(0, size));

    // Pro-Q-style dual spectrum: input (faint grey) + post-filter
    // output (accent), both in the bottom 55% of the plot rect. The
    // painter is wired to repaint when either notifier fires.
    final specRect = Rect.fromLTWH(
      plot.left,
      plot.top + plot.height * 0.45,
      plot.width,
      plot.height * 0.55,
    );
    final pre = preBands.value;
    if (pre != null && pre.isNotEmpty) {
      SpectrumCurve.paintOn(
        canvas,
        specRect,
        pre,
        peakBands: preHold?.bands,
        color: ConsoleSkin.fgFaint,
        fillAlpha: 0.18,
        strokeWidth: 1.0,
        tiltDbPerOctave: 4.5,
      );
    }
    final post = postBands.value;
    if (post != null && post.isNotEmpty) {
      SpectrumCurve.paintOn(
        canvas,
        specRect,
        post,
        peakBands: postHold?.bands,
        color: ConsoleSkin.accent,
        fillAlpha: 0.25,
        strokeWidth: 1.2,
        tiltDbPerOctave: 4.5,
      );
    }

    // Ghost curves — individual response of the selected and/or
    // hovered band, drawn under the summed curve so the user can read
    // what a single band does without it being absorbed into the
    // overlap-summed shape. Only meaningful with more than one band;
    // with a single band, ghost ≡ summed. Hover ghost is drawn first
    // (fainter) so the selected ghost sits on top when both refer to
    // different bands.
    if (bands.length > 1) {
      final hIdx = hoveredIdx;
      if (hIdx != null && hIdx < bands.length && hIdx != selectedIdx) {
        _drawGhost(canvas, size, bands[hIdx],
            color: _bandColor(hIdx).withValues(alpha: 0.35));
      }
      final sIdx = selectedIdx;
      if (sIdx != null && sIdx < bands.length) {
        _drawGhost(canvas, size, bands[sIdx],
            color: _bandColor(sIdx).withValues(alpha: 0.6));
      }
    }

    // Summed response curve — the actual EQ output, drawn on top of
    // the ghost. With 1 band this coincides with the ghost; with N
    // bands it deviates wherever responses overlap.
    if (bands.isNotEmpty) {
      final path = Path();
      const steps = 240;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final f = _fMin * math.pow(_fMax / _fMin, t).toDouble();
        final db = _summedDb(f);
        final x = _xOfStatic(f, size);
        final y = _yOfStatic(db, size);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = ConsoleSkin.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }

    // Markers, with hover / selection highlight. Three states:
    //   normal   r=4.5  thin grey contour
    //   hovered  r=5.5  brighter contour, signals "you can click me"
    //   selected r=6.5  full-foreground contour, thickest stroke
    // Selected wins over hovered when both apply to the same marker.
    for (var i = 0; i < bands.length; i++) {
      final b = bands[i];
      final mx = _xOfStatic(b.frequency, size);
      final my = _yOfStatic(b.gain, size);
      final selected = i == selectedIdx;
      final hovered = !selected && i == hoveredIdx;
      final r = selected ? 6.5 : (hovered ? 5.5 : 4.5);
      final hue = _bandColor(i);
      canvas.drawCircle(
        Offset(mx, my),
        r,
        Paint()..color = hue,
      );
      canvas.drawCircle(
        Offset(mx, my),
        r,
        Paint()
          ..color = selected
              ? ConsoleSkin.fg
              : (hovered ? ConsoleSkin.fg : ConsoleSkin.fgDim)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.0 : (hovered ? 1.6 : 1.2)
          ..isAntiAlias = true,
      );
      // Tiny per-marker label: 1-based index, in the band's hue.
      _drawLabel(
        canvas,
        '${i + 1}',
        Offset(mx + r + 2, my - 7),
        hue,
      );
    }

    _drawAxisLabels(canvas, size);
  }

  void _drawGhost(
    Canvas canvas,
    Size size,
    AnequalizerBand band, {
    required Color color,
  }) {
    final ghost = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final f = _fMin * math.pow(_fMax / _fMin, t).toDouble();
      final db = _bandDb(band, f);
      final x = _xOfStatic(f, size);
      final y = _yOfStatic(db, size);
      if (i == 0) {
        ghost.moveTo(x, y);
      } else {
        ghost.lineTo(x, y);
      }
    }
    canvas.drawPath(
      ghost,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
    ))
      ..pushStyle(ui.TextStyle(color: color, fontSize: ConsoleSkin.sizeTiny))
      ..addText(text);
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 32));
    canvas.drawParagraph(p, offset);
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    for (final f in PlotChrome.freqMajor) {
      PlotChrome.drawXLabel(
          canvas, size, _xOfStatic(f, size), PlotChrome.formatHz(f));
    }
    for (final db in _dbGridMajor) {
      final txt = '${db > 0 ? '+' : ''}$db';
      PlotChrome.drawYLabelRight(
        canvas,
        size,
        _yOfStatic(db.toDouble(), size),
        txt,
        color: db == 0 ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint,
      );
    }
  }

  @override
  bool shouldRepaint(_AnEqGraphPainter old) =>
      old.bands != bands ||
      old.selectedIdx != selectedIdx ||
      old.hoveredIdx != hoveredIdx;
  // preBands / postBands are Listenables, not data — the `repaint`
  // ctor argument is what triggers spectrum repaints, not field
  // identity comparison.
}

// ──────────────────────────────────────────────────────────────────────
// Controls — three knobs (frequency, gain, Q) scoped to the currently-
// selected band. Knobs are always visible; they go disabled when no
// band is selected. Add / remove happen on the graph itself: single
// click on empty area adds a band, right-click on a marker removes it.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final AnequalizerSettings settings;
  final List<AnequalizerBand> bands;
  final int? selectedIdx;
  final ValueChanged<List<AnequalizerBand>> onUpdate;

  const _Controls({
    required this.settings,
    required this.bands,
    required this.selectedIdx,
    required this.onUpdate,
  });

  double _toLog(double f) =>
      (math.log(f.clamp(_fMin, _fMax) / _fMin) / math.log(_fMax / _fMin));
  double _fromLog(double t) => _fMin * math.pow(_fMax / _fMin, t).toDouble();

  @override
  Widget build(BuildContext context) {
    final sel = selectedIdx;
    final band = (sel != null && sel < bands.length) ? bands[sel] : null;
    final hasBand = band != null;
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AtomKnob(
            value: hasBand ? _toLog(band.frequency) : _toLog(1000),
            min: 0,
            max: 1,
            defaultValue: _toLog(1000),
            enabled: hasBand,
            onChanged: (t) {
              final next = [...bands];
              next[sel!] = next[sel].copyWith(frequency: _fromLog(t));
              onUpdate(next);
            },
            label: 'frequency',
            format: (t) {
              final hz = _fromLog(t);
              if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}k';
              return hz.toStringAsFixed(0);
            },
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: hasBand ? band.gain : 0,
            min: -24,
            max: 24,
            defaultValue: 0,
            bipolar: true,
            enabled: hasBand,
            onChanged: (v) {
              final next = [...bands];
              next[sel!] = next[sel].copyWith(gain: v);
              onUpdate(next);
            },
            label: 'gain dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: hasBand ? band.q.clamp(0.1, 10.0) : 1.0,
            min: 0.1,
            max: 10,
            defaultValue: 1.0,
            enabled: hasBand,
            onChanged: (q) {
              final newBw = band!.frequency / q.clamp(0.1, 100);
              final next = [...bands];
              next[sel!] = next[sel].copyWith(bandwidth: newBw);
              onUpdate(next);
            },
            label: 'Q',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          // Filter shape selector — anequalizer's `t` parameter:
          // butterworth / chebyshev1 / chebyshev2.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AtomDropdown<AnequalizerBandType>(
                value: hasBand
                    ? band.type
                    : AnequalizerBandType.butterworth,
                options: const [
                  AnequalizerBandType.butterworth,
                  AnequalizerBandType.chebyshev1,
                  AnequalizerBandType.chebyshev2,
                ],
                enabled: hasBand,
                onChanged: (t) {
                  final next = [...bands];
                  next[sel!] = next[sel].copyWith(type: t);
                  onUpdate(next);
                },
                format: (t) => switch (t) {
                  AnequalizerBandType.butterworth => 'butter',
                  AnequalizerBandType.chebyshev1 => 'cheby1',
                  AnequalizerBandType.chebyshev2 => 'cheby2',
                },
                width: 80,
                height: 22,
              ),
              const SizedBox(height: 3),
              const Text(
                'shape',
                style: TextStyle(
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgDim,
                  fontFamily: ConsoleSkin.fontMono,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
