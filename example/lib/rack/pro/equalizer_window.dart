import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_spectrum_curve.dart';
import '../../atoms/pcm_band_processor.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `equalizer` filter (single-band peak
/// EQ). Frequency response curve at the top with the live FFT spectrum
/// as a dim background; two knobs (frequency, gain) below.
///
/// The lavfi `equalizer` filter exposes both `f`/`frequency` and
/// `g`/`gain` aliases; we read/write through the long-form names. Width
/// (Q) isn't exposed as a typed field in this binding, so the visualised
/// bell uses a fixed width of 0.5 octaves.
class EqualizerWindow extends StatelessWidget {
  final VoidCallback onClose;
  const EqualizerWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.equalizer;
        return ProPluginWindow(
          filterName: 'equalizer',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Graph: live spectrum (faint) + EQ response curve (accent) + grid.
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final EqualizerSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

// Shared with the painter so the drag math inverts the same mapping.
const double _fMin = 20;
const double _fMax = 20000;
const double _dbMin = -24;
const double _dbMax = 24;

class _GraphState extends State<_Graph> {
  // Two FFT processors fed by the per-filter pre / post taps. The
  // band snapshots flow into a pair of ValueNotifiers so the
  // CustomPaint repaints WITHOUT rebuilding the widget tree —
  // setState at 60 Hz on a complex pro-window subtree was
  // measurably laggy.
  final _preProc = PcmBandProcessor();
  final _postProc = PcmBandProcessor();
  final _preBands = ValueNotifier<Float32List?>(null);
  final _postBands = ValueNotifier<Float32List?>(null);
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;

  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _preSub = widget.player.tapPre('equalizer').listen((frame) {
      if (!mounted) return;
      _preBands.value = _preProc.process(frame);
    });
    _postSub = widget.player.tapPost('equalizer').listen((frame) {
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

  void _setFromPosition(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final tX = (local.dx / size.width).clamp(0.0, 1.0);
    final newFreq = _fMin * math.pow(_fMax / _fMin, tX).toDouble();
    final tY = (1 - (local.dy / size.height).clamp(0.0, 1.0));
    final newGain = _dbMin + tY * (_dbMax - _dbMin);
    widget.player.updateAudioEffects(
      (b) => b.copyWith(
        equalizer: widget.settings.copyWith(
          frequency: newFreq.clamp(_fMin, _fMax),
          gain: newGain.clamp(_dbMin, _dbMax),
        ),
      ),
    );
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
            onPanStart: (d) {
              setState(() => _dragging = true);
              _setFromPosition(d.localPosition, size);
            },
            onPanUpdate: (d) => _setFromPosition(d.localPosition, size),
            onPanEnd: (_) => setState(() => _dragging = false),
            onTapDown: (d) => _setFromPosition(d.localPosition, size),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _EqGraphPainter(
                  frequency: widget.settings.frequency,
                  gainDb: widget.settings.gain,
                  q: widget.settings.width,
                  preBands: _preBands,
                  postBands: _postBands,
                  dragging: _dragging,
                ),
                size: Size.infinite,
                isComplex: true,
                willChange: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EqGraphPainter extends CustomPainter {
  final double frequency;
  final double gainDb;
  final double q;
  final ValueListenable<Float32List?> preBands;
  final ValueListenable<Float32List?> postBands;
  final bool dragging;

  // Fixed grid lines drawn behind both the spectrum and the EQ curve.
  // Keeping decade marks lets the eye relate frequency knob value to
  // a visual landmark instantly.
  static const _freqGrid = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
  static const _dbGrid = [-18, -12, -6, 0, 6, 12, 18];

  _EqGraphPainter({
    required this.frequency,
    required this.gainDb,
    required this.q,
    required this.preBands,
    required this.postBands,
    required this.dragging,
  }) : super(repaint: Listenable.merge([preBands, postBands]));

  /// Convert a Q-factor to half-bandwidth in octaves. Standard formula:
  ///   bw_octaves = (2/ln(2)) * asinh(1/(2Q))
  /// Half of that is the σ used in the bell shape.
  static double _qToHalfBwOctaves(double q) {
    final qq = q.clamp(0.05, 100.0);
    final x = 1.0 / (2.0 * qq);
    final asinh = math.log(x + math.sqrt(x * x + 1));
    return (2.0 / math.log(2)) * asinh / 2.0;
  }

  static double _xOf(double f, Size size) {
    final t = (math.log(f / _fMin) / math.log(_fMax / _fMin))
        .clamp(0.0, 1.0);
    return size.width * t;
  }

  static double _yOf(double db, Size size) {
    final t = ((db - _dbMin) / (_dbMax - _dbMin)).clamp(0.0, 1.0);
    return size.height * (1 - t);
  }

  /// Approximate magnitude (dB) of a bell-shaped peaking EQ band at
  /// frequency [f]. Visual approximation — not bit-exact RBJ biquad
  /// math, but reads correctly to the eye and tracks Q.
  double _eqResponseDb(double f) {
    if (frequency <= 0 || gainDb == 0) return 0;
    final halfBw = _qToHalfBwOctaves(q);
    if (halfBw <= 0) return 0;
    final octs = math.log(f / frequency) / math.log(2);
    final w = octs / halfBw;
    return gainDb * math.exp(-w * w);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background well.
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    // Grid: vertical decade marks.
    final gridPaint = Paint()
      ..color = ConsoleSkin.hairline
      ..strokeWidth = ConsoleSkin.hairlinePx
      ..isAntiAlias = false;
    for (final f in _freqGrid) {
      final x = _xOf(f.toDouble(), size).floorToDouble() + 0.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Grid: horizontal dB marks.
    for (final db in _dbGrid) {
      final y = _yOf(db.toDouble(), size).floorToDouble() + 0.5;
      final color = db == 0 ? ConsoleSkin.fgFaint : ConsoleSkin.hairline;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = color
          ..strokeWidth = ConsoleSkin.hairlinePx
          ..isAntiAlias = false,
      );
    }

    // Pro-Q-style dual spectrum: input (faint grey) + post-filter
    // output (accent), both drawn in the bottom 55% so they never
    // collide with the EQ-response curve at extreme gains. Read the
    // notifiers' current values directly — the painter has been
    // wired to repaint when either of them notifies (see ctor).
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

    // EQ response curve.
    final path = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final f = _fMin * math.pow(_fMax / _fMin, t).toDouble();
      final db = _eqResponseDb(f);
      final x = _xOf(f, size);
      final y = _yOf(db, size);
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

    // Marker at the band's centre (frequency, gain). Larger + ringed
    // while dragging so the active state is unambiguous.
    if (frequency > 0) {
      final mx = _xOf(frequency, size);
      final my = _yOf(gainDb, size);
      final r = dragging ? 6.5 : 4.5;
      canvas.drawCircle(
        Offset(mx, my),
        r,
        Paint()..color = ConsoleSkin.accentHot,
      );
      canvas.drawCircle(
        Offset(mx, my),
        r,
        Paint()
          ..color = ConsoleSkin.fg
          ..style = PaintingStyle.stroke
          ..strokeWidth = dragging ? 2.0 : 1.2
          ..isAntiAlias = true,
      );
      if (dragging) {
        // Vertical guide line through the marker for visual alignment
        // with the frequency axis labels.
        canvas.drawLine(
          Offset(mx, 0),
          Offset(mx, size.height),
          Paint()
            ..color = ConsoleSkin.accentDim
            ..strokeWidth = ConsoleSkin.hairlinePx
            ..isAntiAlias = false,
        );
      }
    }

    // Axis labels (right edge: dB, bottom: a few Hz markers).
    _drawAxisLabels(canvas, size);
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    final labels = <(double, String)>[
      (50, '50'),
      (100, '100'),
      (1000, '1k'),
      (10000, '10k'),
    ];
    for (final (f, txt) in labels) {
      final x = _xOf(f, size);
      _paragraph(txt, color: ConsoleSkin.fgDim).draw(canvas, Offset(x + 2, size.height - 12));
    }
    for (final db in [-12, 0, 12]) {
      final y = _yOf(db.toDouble(), size);
      _paragraph(
        '${db > 0 ? '+' : ''}$db',
        color: db == 0 ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint,
      ).draw(canvas, Offset(size.width - 22, y - 4));
    }
  }

  _Paragraph _paragraph(String text, {required Color color}) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
    ))
      ..pushStyle(ui.TextStyle(color: color, fontSize: ConsoleSkin.sizeTiny))
      ..addText(text);
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 64));
    return _Paragraph(p);
  }

  @override
  bool shouldRepaint(_EqGraphPainter old) =>
      old.frequency != frequency ||
      old.gainDb != gainDb ||
      old.q != q ||
      old.dragging != dragging;
  // preBands / postBands are Listenables — the painter's `repaint`
  // ctor arg drives spectrum repaints, no identity check needed.
}

class _Paragraph {
  final ui.Paragraph p;
  _Paragraph(this.p);
  void draw(Canvas canvas, Offset offset) => canvas.drawParagraph(p, offset);
}

// ──────────────────────────────────────────────────────────────────────
// Controls: frequency + gain knobs. Frequency uses log mapping so the
// drag travel feels even across the audible range.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final EqualizerSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  static const double _fMin = 20;
  static const double _fMax = 20000;

  // Knob position is 0..1 in log space; convert to/from Hz.
  double _toLog(double f) =>
      (math.log(f.clamp(_fMin, _fMax) / _fMin) / math.log(_fMax / _fMin));
  double _fromLog(double t) => _fMin * math.pow(_fMax / _fMin, t).toDouble();

  @override
  Widget build(BuildContext context) {
    final fLog = _toLog(settings.frequency <= 0 ? 1000 : settings.frequency);
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AtomKnob(
            value: fLog,
            min: 0,
            max: 1,
            defaultValue: _toLog(1000),
            onChanged: (t) => player.updateAudioEffects(
              (b) => b.copyWith(
                equalizer: settings.copyWith(frequency: _fromLog(t)),
              ),
            ),
            label: 'frequency',
            format: (t) {
              final hz = _fromLog(t);
              if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}k';
              return hz.toStringAsFixed(0);
            },
            size: 56,
          ),
          const SizedBox(width: 24),
          AtomKnob(
            value: settings.gain,
            min: -24,
            max: 24,
            defaultValue: 0,
            onChanged: (v) => player.updateAudioEffects(
              (b) => b.copyWith(equalizer: settings.copyWith(gain: v)),
            ),
            label: 'gain dB',
            format: (v) =>
                '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 56,
          ),
          const SizedBox(width: 24),
          AtomKnob(
            value: settings.width <= 0 ? 1.0 : settings.width,
            min: 0.1,
            max: 10,
            defaultValue: 1.0,
            onChanged: (v) => player.updateAudioEffects(
              (b) => b.copyWith(equalizer: settings.copyWith(width: v)),
            ),
            label: 'Q',
            format: (v) => v.toStringAsFixed(2),
            size: 56,
          ),
        ],
      ),
    );
  }
}

// Registry / openProWindow helper now live in `pro_registry.dart` so
// every filter window stays a leaf concern.
