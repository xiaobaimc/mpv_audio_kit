import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_spectrum_curve.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `firequalizer` — an FIR equalizer
/// driven by a list of `(frequency, gain)` entries that the engine
/// interpolates into an arbitrary frequency response. Unlike biquad
/// EQs, the curve here can have any shape (vertical jumps, flat
/// shelves, sharp notches) because FIR filters are not constrained to
/// minimum-phase biquad geometry.
///
/// Hero element is a free-form curve editor: every entry is a marker
/// you drag on the dB / log-frequency plane, and the curve between
/// markers is the linear interpolation that lavfi's
/// `gain_interpolate(f)` default uses. Click empty area to add a
/// marker, right-click to remove.
///
/// Reference: iZotope Equalizer's "draw" mode, FabFilter Pro-Q's
/// "linear phase" tab. Both expose the same metaphor — drag points,
/// engine renders the FIR.
class FirequalizerWindow extends StatelessWidget {
  final VoidCallback onClose;
  const FirequalizerWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.firequalizer;
        return ProPluginWindow(
          filterName: 'firequalizer',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          // No knob row — every parameter is on the curve itself.
          controls: const SizedBox.shrink(),
        );
      },
    );
  }
}

const double _fMin = 20;
const double _fMax = 20000;
const double _dbMin = -24;
const double _dbMax = 24;

// Gain entries are read / written through the lib-side
// [FirequalizerEntriesX] extension — the `entry(freq,gain);…`
// grammar lives in
// `lib/src/types/settings/extensions/firequalizer_entries.dart`.

class _Graph extends StatefulWidget {
  final FirequalizerSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  int? _hoverIdx;
  int? _dragIdx;

  // Live FFT spectrum behind the FIR curve. Same wiring the bell-EQ
  // windows use — pre + post taps run through [BandProcessor], with a
  // slow-falling peak-hold buffer for the analyzer-style outline.
  final _preBands = ValueNotifier<Float32List?>(null);
  final _postBands = ValueNotifier<Float32List?>(null);
  SpectrumPeakHold? _preHold;
  SpectrumPeakHold? _postHold;
  late final BandProcessor _preProc;
  late final BandProcessor _postProc;
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;
  StreamSubscription<SpectrumSettings>? _cfgSub;

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
        .tap(AudioEffect.firequalizer, side: TapSide.pre)
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
        .tap(AudioEffect.firequalizer, side: TapSide.post)
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
    _preSub?.cancel();
    _postSub?.cancel();
    _cfgSub?.cancel();
    _preBands.dispose();
    _postBands.dispose();
    super.dispose();
  }

  static double _xOfHz(double hz, Size size) {
    final plot = PlotChrome.plotRect(size);
    final t = (math.log(hz.clamp(_fMin, _fMax) / _fMin) /
            math.log(_fMax / _fMin))
        .clamp(0.0, 1.0);
    return plot.left + plot.width * t;
  }

  static double _yOfDb(double db, Size size) {
    final plot = PlotChrome.plotRect(size);
    final t = ((db.clamp(_dbMin, _dbMax) - _dbMin) / (_dbMax - _dbMin))
        .clamp(0.0, 1.0);
    return plot.top + plot.height * (1 - t);
  }

  static double _hzOfX(double x, Size size) {
    final plot = PlotChrome.plotRect(size);
    final t = ((x - plot.left) / plot.width).clamp(0.0, 1.0);
    return _fMin * math.pow(_fMax / _fMin, t).toDouble();
  }

  static double _dbOfY(double y, Size size) {
    final plot = PlotChrome.plotRect(size);
    final t = (1 - ((y - plot.top) / plot.height).clamp(0.0, 1.0));
    return _dbMin + t * (_dbMax - _dbMin);
  }

  int? _hitTest(Offset p, Size size, List<FirequalizerEntry> entries,
      {double tolerance = 14}) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < entries.length; i++) {
      final ex = _xOfHz(entries[i].frequencyHz, size);
      final ey = _yOfDb(entries[i].gainDb, size);
      final d = (Offset(ex, ey) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return bestD <= tolerance && best >= 0 ? best : null;
  }

  void _writeBack(List<FirequalizerEntry> entries) {
    widget.player.updateAudioEffects(
      (b) => b.copyWith(
        firequalizer: widget.settings.withGainEntries(entries),
      ),
    );
  }

  void _addAt(Offset p, Size size, List<FirequalizerEntry> entries) {
    final f = _hzOfX(p.dx, size);
    final g = _dbOfY(p.dy, size);
    final next = [...entries, FirequalizerEntry(frequencyHz: f, gainDb: g)]
      ..sort((a, b) => a.frequencyHz.compareTo(b.frequencyHz));
    _writeBack(next);
    _dragIdx = next.indexWhere((e) => e.frequencyHz == f && e.gainDb == g);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.settings.gainEntries;
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return MouseRegion(
            cursor: _hoverIdx != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.precise,
            onHover: (e) {
              final hit = _hitTest(e.localPosition, size, entries);
              if (hit != _hoverIdx) setState(() => _hoverIdx = hit);
            },
            onExit: (_) {
              if (_hoverIdx != null) setState(() => _hoverIdx = null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final hit = _hitTest(d.localPosition, size, entries);
                if (hit == null) {
                  _addAt(d.localPosition, size, entries);
                }
              },
              onSecondaryTapDown: (d) {
                final hit = _hitTest(d.localPosition, size, entries);
                if (hit == null) return;
                final next = [...entries]..removeAt(hit);
                _writeBack(next);
              },
              onPanStart: (d) {
                final hit = _hitTest(d.localPosition, size, entries);
                if (hit != null) {
                  _dragIdx = hit;
                } else {
                  _addAt(d.localPosition, size, entries);
                }
              },
              onPanUpdate: (d) {
                final i = _dragIdx;
                if (i == null) return;
                final fresh = widget.settings.gainEntries;
                if (i >= fresh.length) return;
                final f = _hzOfX(d.localPosition.dx, size);
                final g = _dbOfY(d.localPosition.dy, size);
                final next = [...fresh];
                next[i] = FirequalizerEntry(frequencyHz: f, gainDb: g);
                next.sort((a, b) => a.frequencyHz.compareTo(b.frequencyHz));
                _writeBack(next);
              },
              onPanEnd: (_) => _dragIdx = null,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _FirPainter(
                    entries: entries,
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
      ),
    );
  }
}

class _FirPainter extends CustomPainter {
  final List<FirequalizerEntry> entries;
  final int? hoveredIdx;
  final ValueListenable<Float32List?> preBands;
  final ValueListenable<Float32List?> postBands;
  final SpectrumPeakHold? preHold;
  final SpectrumPeakHold? postHold;

  _FirPainter({
    required this.entries,
    required this.hoveredIdx,
    required this.preBands,
    required this.postBands,
    required this.preHold,
    required this.postHold,
  }) : super(repaint: Listenable.merge([preBands, postBands]));

  // dB: majors every 6 dB, minors every 3 dB.
  static const _dbGridMajor = [-18, -12, -6, 0, 6, 12, 18];
  static const _dbGridMinor = [-15, -9, -3, 3, 9, 15];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    // Two-tier grid via PlotChrome. Minors painted first so majors
    // (brighter) sit on top and don't get visually masked.
    for (final hz in PlotChrome.freqMinor) {
      PlotChrome.drawVGrid(
          canvas, size, _GraphState._xOfHz(hz, size),
          color: ConsoleSkin.hairline);
    }
    for (final db in _dbGridMinor) {
      PlotChrome.drawHGrid(
          canvas, size, _GraphState._yOfDb(db.toDouble(), size),
          color: ConsoleSkin.hairline);
    }
    for (final hz in PlotChrome.freqMajor) {
      PlotChrome.drawVGrid(
          canvas, size, _GraphState._xOfHz(hz, size),
          color: ConsoleSkin.fgFaint);
    }
    for (final db in _dbGridMajor) {
      if (db == 0) continue;
      PlotChrome.drawHGrid(
          canvas, size, _GraphState._yOfDb(db.toDouble(), size),
          color: ConsoleSkin.hairline);
    }
    PlotChrome.drawZeroH(
        canvas, size, _GraphState._yOfDb(0, size));

    final plot = PlotChrome.plotRect(size);

    // Live spectrum overlay — bottom 55% so it never collides with
    // the FIR curve at extreme gains. Pre = grey, post = accent.
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

    if (entries.isEmpty) {
      _drawHint(canvas, size);
      _drawAxisLabels(canvas, size);
      return;
    }

    // Linear-interp curve between points (matches lavfi's default
    // `gain_interpolate(f)` behaviour). Stretch to plot edges.
    final path = Path();
    final firstY =
        _GraphState._yOfDb(entries.first.gainDb, size);
    path.moveTo(plot.left, firstY);
    for (final e in entries) {
      path.lineTo(_GraphState._xOfHz(e.frequencyHz, size),
          _GraphState._yOfDb(e.gainDb, size));
    }
    final lastY = _GraphState._yOfDb(entries.last.gainDb, size);
    path.lineTo(plot.right, lastY);
    canvas.drawPath(
      path,
      Paint()
        ..color = ConsoleSkin.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // Markers.
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final x = _GraphState._xOfHz(e.frequencyHz, size);
      final y = _GraphState._yOfDb(e.gainDb, size);
      final hovered = i == hoveredIdx;
      final r = hovered ? 5.5 : 4.5;
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = ConsoleSkin.accentHot);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = hovered ? ConsoleSkin.fg : ConsoleSkin.fgDim
          ..style = PaintingStyle.stroke
          ..strokeWidth = hovered ? 1.6 : 1.2
          ..isAntiAlias = true,
      );
    }

    _drawAxisLabels(canvas, size);
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    for (final hz in PlotChrome.freqMajor) {
      PlotChrome.drawXLabel(
        canvas,
        size,
        _GraphState._xOfHz(hz, size),
        PlotChrome.formatHz(hz),
      );
    }
    for (final db in _dbGridMajor) {
      PlotChrome.drawYLabelRight(
        canvas,
        size,
        _GraphState._yOfDb(db.toDouble(), size),
        '${db > 0 ? '+' : ''}$db',
      );
    }
  }

  void _drawHint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    _drawText(
      canvas,
      'click anywhere to add a point',
      Offset(plot.center.dx - 90, plot.center.dy - 6),
      ConsoleSkin.fgFaint,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
    ))
      ..pushStyle(ui.TextStyle(color: color, fontSize: ConsoleSkin.sizeTiny))
      ..addText(text);
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 200));
    canvas.drawParagraph(p, offset);
  }

  @override
  bool shouldRepaint(_FirPainter old) =>
      old.entries.length != entries.length ||
      old.hoveredIdx != hoveredIdx ||
      _entriesChanged(old.entries, entries);

  bool _entriesChanged(List<FirequalizerEntry> a, List<FirequalizerEntry> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].frequencyHz != b[i].frequencyHz || a[i].gainDb != b[i].gainDb) {
        return true;
      }
    }
    return false;
  }
}
