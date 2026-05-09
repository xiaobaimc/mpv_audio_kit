import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../atoms/atom_button.dart';
import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_spectrum_curve.dart';
import '../../atoms/pcm_band_processor.dart';
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
            onAddDefault: () {
              final next = [...bands, _defaultBand()];
              _writeBack(p, s, next);
              setState(() => _selected = next.length - 1);
            },
            onRemoveSelected: sel == null
                ? null
                : () {
                    final next = [...bands]..removeAt(sel);
                    _writeBack(p, s, next);
                    setState(() => _selected = null);
                  },
          ),
        );
      },
    );
  }
}

AnequalizerBand _defaultBand() => const AnequalizerBand(
      frequency: 1000,
      bandwidth: 1000,
      gain: 0,
    );

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
  // Two FFT processors fed by the per-filter pre / post taps. The
  // band snapshots flow into ValueNotifiers so the CustomPaint
  // repaints WITHOUT rebuilding the (heavy) widget tree.
  final _preProc = PcmBandProcessor();
  final _postProc = PcmBandProcessor();
  final _preBands = ValueNotifier<Float32List?>(null);
  final _postBands = ValueNotifier<Float32List?>(null);
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;

  // Index of the band the cursor is currently dragging, if any.
  int? _dragIdx;

  @override
  void initState() {
    super.initState();
    _preSub = widget.player.tapPre('anequalizer').listen((frame) {
      if (!mounted) return;
      _preBands.value = _preProc.process(frame);
    });
    _postSub = widget.player.tapPost('anequalizer').listen((frame) {
      if (!mounted) return;
      _postBands.value = _postProc.process(frame);
    });
  }

  @override
  void dispose() {
    _preSub?.cancel();
    _postSub?.cancel();
    _preBands.dispose();
    _postBands.dispose();
    super.dispose();
  }

  // Inverse of [_xOf] / [_yOf] in the painter — kept here so onPanStart
  // / onTapDown stay simple and don't need painter access.
  double _freqAt(double dx, double width) {
    final t = (dx / width).clamp(0.0, 1.0);
    return _fMin * math.pow(_fMax / _fMin, t).toDouble();
  }

  double _gainAt(double dy, double height) {
    final t = (1 - (dy / height).clamp(0.0, 1.0));
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
    final f = _freqAt(pos.dx, size.width);
    final g = _gainAt(pos.dy, size.height);
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
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final i = _dragIdx;
    if (i == null || i >= widget.bands.length) return;
    final f = _freqAt(d.localPosition.dx, size.width);
    final g = _gainAt(d.localPosition.dy, size.height);
    final next = [...widget.bands];
    next[i] = next[i].copyWith(
      frequency: f.clamp(_fMin, _fMax),
      gain: g.clamp(_dbMin, _dbMax),
    );
    widget.onUpdate(next);
  }

  void _onPanEnd(DragEndDetails _) {
    _dragIdx = null;
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
        return MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPanStart(d, size),
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: _onPanEnd,
            onTapDown: (d) => _onTapDown(d, size),
            onSecondaryTapDown: (d) => _onSecondaryTapDown(d, size),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AnEqGraphPainter(
                  bands: widget.bands,
                  selectedIdx: widget.selectedIdx,
                  preBands: _preBands,
                  postBands: _postBands,
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
  final t = (math.log(f.clamp(_fMin, _fMax) / _fMin) /
          math.log(_fMax / _fMin))
      .clamp(0.0, 1.0);
  return size.width * t;
}

double _yOfStatic(double db, Size size) {
  final t = ((db.clamp(_dbMin, _dbMax) - _dbMin) / (_dbMax - _dbMin))
      .clamp(0.0, 1.0);
  return size.height * (1 - t);
}

class _AnEqGraphPainter extends CustomPainter {
  final List<AnequalizerBand> bands;
  final int? selectedIdx;
  final ValueListenable<Float32List?> preBands;
  final ValueListenable<Float32List?> postBands;

  static const _freqGrid = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
  static const _dbGrid = [-18, -12, -6, 0, 6, 12, 18];

  _AnEqGraphPainter({
    required this.bands,
    required this.selectedIdx,
    required this.preBands,
    required this.postBands,
  }) : super(repaint: Listenable.merge([preBands, postBands]));

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
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    // Grid.
    for (final f in _freqGrid) {
      final x = _xOfStatic(f.toDouble(), size).floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = ConsoleSkin.hairline
          ..strokeWidth = ConsoleSkin.hairlinePx
          ..isAntiAlias = false,
      );
    }
    for (final db in _dbGrid) {
      final y = _yOfStatic(db.toDouble(), size).floorToDouble() + 0.5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = db == 0 ? ConsoleSkin.fgFaint : ConsoleSkin.hairline
          ..strokeWidth = ConsoleSkin.hairlinePx
          ..isAntiAlias = false,
      );
    }

    // Pro-Q-style dual spectrum: input (faint grey) + post-filter
    // output (accent), both in the bottom 55%. The painter is wired
    // to repaint when either notifier fires (see ctor) so reading
    // .value here always reflects the latest snapshot.
    final specRect = Rect.fromLTWH(
      0,
      size.height * 0.45,
      size.width,
      size.height * 0.55,
    );
    final pre = preBands.value;
    if (pre != null && pre.isNotEmpty) {
      SpectrumCurve.paintOn(
        canvas,
        specRect,
        pre,
        color: ConsoleSkin.fgFaint,
        fillAlpha: 0.18,
        strokeWidth: 1.0,
      );
    }
    final post = postBands.value;
    if (post != null && post.isNotEmpty) {
      SpectrumCurve.paintOn(
        canvas,
        specRect,
        post,
        color: ConsoleSkin.accent,
        fillAlpha: 0.25,
        strokeWidth: 1.2,
      );
    }

    // Ghost curve — selected band's INDIVIDUAL response, drawn faintly
    // under the summed curve. Passes exactly through the selected
    // marker, so the user sees that the marker positions a single
    // band even when overlapping bands shift the summed curve away.
    // Only meaningful when there's more than one band: with 1 band
    // ghost ≡ summed.
    final sIdx = selectedIdx;
    if (sIdx != null && sIdx < bands.length && bands.length > 1) {
      final ghost = Path();
      const steps = 240;
      final selBand = bands[sIdx];
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final f = _fMin * math.pow(_fMax / _fMin, t).toDouble();
        final db = _bandDb(selBand, f);
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
          ..color = ConsoleSkin.accentDim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
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

    // Markers, with selection highlight.
    for (var i = 0; i < bands.length; i++) {
      final b = bands[i];
      final mx = _xOfStatic(b.frequency, size);
      final my = _yOfStatic(b.gain, size);
      final selected = i == selectedIdx;
      final r = selected ? 6.5 : 4.5;
      canvas.drawCircle(
        Offset(mx, my),
        r,
        Paint()..color = ConsoleSkin.accentHot,
      );
      canvas.drawCircle(
        Offset(mx, my),
        r,
        Paint()
          ..color = selected ? ConsoleSkin.fg : ConsoleSkin.fgDim
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.0 : 1.2
          ..isAntiAlias = true,
      );
      // Tiny per-marker label: 1-based index.
      _drawLabel(
        canvas,
        '${i + 1}',
        Offset(mx + r + 2, my - 7),
        selected ? ConsoleSkin.fg : ConsoleSkin.fgDim,
      );
    }

    _drawAxisLabels(canvas, size);
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
    const labels = <(double, String)>[
      (50, '50'),
      (100, '100'),
      (1000, '1k'),
      (10000, '10k'),
    ];
    for (final (f, txt) in labels) {
      final x = _xOfStatic(f, size);
      _drawLabel(
        canvas,
        txt,
        Offset(x + 2, size.height - 12),
        ConsoleSkin.fgDim,
      );
    }
    for (final db in [-12, 0, 12]) {
      final y = _yOfStatic(db.toDouble(), size);
      _drawLabel(
        canvas,
        '${db > 0 ? '+' : ''}$db',
        Offset(size.width - 22, y - 4),
        db == 0 ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint,
      );
    }
  }

  @override
  bool shouldRepaint(_AnEqGraphPainter old) =>
      old.bands != bands ||
      old.selectedIdx != selectedIdx;
  // preBands / postBands are Listenables, not data — the `repaint`
  // ctor argument is what triggers spectrum repaints, not field
  // identity comparison.
}

// ──────────────────────────────────────────────────────────────────────
// Controls — toolbar (band count + add + remove) on top, then knobs
// scoped to the currently-selected band.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final AnequalizerSettings settings;
  final List<AnequalizerBand> bands;
  final int? selectedIdx;
  final ValueChanged<List<AnequalizerBand>> onUpdate;
  final VoidCallback onAddDefault;
  final VoidCallback? onRemoveSelected;

  const _Controls({
    required this.settings,
    required this.bands,
    required this.selectedIdx,
    required this.onUpdate,
    required this.onAddDefault,
    required this.onRemoveSelected,
  });

  double _toLog(double f) =>
      (math.log(f.clamp(_fMin, _fMax) / _fMin) / math.log(_fMax / _fMin));
  double _fromLog(double t) => _fMin * math.pow(_fMax / _fMin, t).toDouble();

  @override
  Widget build(BuildContext context) {
    final sel = selectedIdx;
    final band = (sel != null && sel < bands.length) ? bands[sel] : null;
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            count: bands.length,
            selectedIdx: sel,
            onAdd: onAddDefault,
            onRemove: onRemoveSelected,
          ),
          const SizedBox(height: 6),
          Container(
            height: ConsoleSkin.hairlinePx,
            color: ConsoleSkin.hairline,
          ),
          const SizedBox(height: 6),
          if (band == null)
            const SizedBox(
              height: 80,
              child: Center(
                child: AtomLabel(
                  'click on the graph to add a band, or click an existing marker',
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgFaint,
                  mono: true,
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AtomKnob(
                  value: _toLog(band.frequency),
                  min: 0,
                  max: 1,
                  defaultValue: _toLog(1000),
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
                  size: 50,
                ),
                const SizedBox(width: 16),
                AtomKnob(
                  value: band.gain,
                  min: -24,
                  max: 24,
                  defaultValue: 0,
                  onChanged: (v) {
                    final next = [...bands];
                    next[sel!] = next[sel].copyWith(gain: v);
                    onUpdate(next);
                  },
                  label: 'gain dB',
                  format: (v) =>
                      '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
                  size: 50,
                ),
                const SizedBox(width: 16),
                AtomKnob(
                  value: band.q.clamp(0.1, 10.0),
                  min: 0.1,
                  max: 10,
                  defaultValue: 1.0,
                  onChanged: (q) {
                    final newBw = band.frequency / q.clamp(0.1, 100);
                    final next = [...bands];
                    next[sel!] = next[sel].copyWith(bandwidth: newBw);
                    onUpdate(next);
                  },
                  label: 'Q',
                  format: (v) => v.toStringAsFixed(2),
                  size: 50,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final int count;
  final int? selectedIdx;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const _Toolbar({
    required this.count,
    required this.selectedIdx,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final selLabel = selectedIdx != null
        ? 'band ${selectedIdx! + 1} / $count'
        : count == 0
            ? 'no bands'
            : '$count band${count == 1 ? '' : 's'}';
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AtomLabel(
              selLabel,
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.fgDim,
              mono: true,
            ),
          ),
          const Spacer(),
          AtomButton(
            label: 'ADD',
            onTap: onAdd,
            width: 48,
            height: 20,
          ),
          AtomButton(
            label: 'REMOVE',
            onTap: onRemove ?? () {},
            enabled: onRemove != null,
            width: 64,
            height: 20,
          ),
        ],
      ),
    );
  }
}
