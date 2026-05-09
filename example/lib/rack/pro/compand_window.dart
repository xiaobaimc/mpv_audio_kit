import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `compand`. Hero element is a
/// **transfer-function curve editor** with draggable `(in_dB, out_dB)`
/// points — anywhere on the line you click adds a new point, drag
/// repositions it, right-click removes. Same metaphor every classic
/// compander UI uses (sox `compand`, Logic Compressor in "transfer"
/// mode, Cubase compand). The curve between points is a polyline,
/// matching lavfi's behaviour.
///
/// Controls below the curve: gain, volume, delay knobs. The attack /
/// decay envelopes are CSV strings — they live as a debug-level
/// metadata strip rather than a knob, since editing them visually
/// would require a dedicated time-axis painter.
class CompandWindow extends StatelessWidget {
  final VoidCallback onClose;
  const CompandWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.compand;
        return ProPluginWindow(
          filterName: 'compand',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

const double _dbFloor = -80;
const double _dbCeil = 0;

// Transfer points are read / written through the lib-side
// [CompandPointsX] extension — the space-separated `inDb/outDb`
// grammar lives in
// `lib/src/types/settings/extensions/compand_points.dart`.

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

double _dbOfX(double x, Size size) {
  final plot = PlotChrome.plotRect(size);
  final t = ((x - plot.left) / plot.width).clamp(0.0, 1.0);
  return _dbFloor + t * (_dbCeil - _dbFloor);
}

double _dbOfY(double y, Size size) {
  final plot = PlotChrome.plotRect(size);
  final t = (1 - ((y - plot.top) / plot.height).clamp(0.0, 1.0));
  return _dbFloor + t * (_dbCeil - _dbFloor);
}

class _Graph extends StatefulWidget {
  final CompandSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  int? _hoverIdx;
  int? _dragIdx;

  int? _hitTest(Offset p, Size size, List<CompandPoint> pts,
      {double tolerance = 14}) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final ex = _xOfDb(pts[i].inDb, size);
      final ey = _yOfDb(pts[i].outDb, size);
      final d = (Offset(ex, ey) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return bestD <= tolerance && best >= 0 ? best : null;
  }

  void _writeBack(List<CompandPoint> pts) {
    widget.player.updateAudioEffects(
      (b) => b.copyWith(
        compand: widget.settings.withTransferPoints(pts),
      ),
    );
  }

  void _addAt(Offset p, Size size, List<CompandPoint> pts) {
    final inDb = _dbOfX(p.dx, size);
    final outDb = _dbOfY(p.dy, size);
    final next = [...pts, CompandPoint(inDb: inDb, outDb: outDb)]
      ..sort((a, b) => a.inDb.compareTo(b.inDb));
    _writeBack(next);
    _dragIdx = next.indexWhere((q) => q.inDb == inDb && q.outDb == outDb);
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.settings.transferPoints;
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
              final hit = _hitTest(e.localPosition, size, pts);
              if (hit != _hoverIdx) setState(() => _hoverIdx = hit);
            },
            onExit: (_) {
              if (_hoverIdx != null) setState(() => _hoverIdx = null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final hit = _hitTest(d.localPosition, size, pts);
                if (hit == null) _addAt(d.localPosition, size, pts);
              },
              onSecondaryTapDown: (d) {
                final hit = _hitTest(d.localPosition, size, pts);
                if (hit == null) return;
                final next = [...pts]..removeAt(hit);
                _writeBack(next);
              },
              onPanStart: (d) {
                final hit = _hitTest(d.localPosition, size, pts);
                if (hit != null) {
                  _dragIdx = hit;
                } else {
                  _addAt(d.localPosition, size, pts);
                }
              },
              onPanUpdate: (d) {
                final i = _dragIdx;
                if (i == null) return;
                final fresh = widget.settings.transferPoints;
                if (i >= fresh.length) return;
                final inDb = _dbOfX(d.localPosition.dx, size);
                final outDb = _dbOfY(d.localPosition.dy, size);
                final next = [...fresh];
                next[i] = CompandPoint(inDb: inDb, outDb: outDb);
                next.sort((a, b) => a.inDb.compareTo(b.inDb));
                _writeBack(next);
              },
              onPanEnd: (_) => _dragIdx = null,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _CompandPainter(
                    points: pts,
                    hoveredIdx: _hoverIdx,
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

class _CompandPainter extends CustomPainter {
  final List<CompandPoint> points;
  final int? hoveredIdx;
  _CompandPainter({required this.points, required this.hoveredIdx});

  // Major (labeled) every 12 dB; minor (un-labeled, dimmer) at the
  // 6 dB midpoints. Same two-tier pattern as acompressor / agate so
  // every "knee plot" reads identically across the rack.
  static const _gridDbMajor = [-72, -60, -48, -36, -24, -12, 0];
  static const _gridDbMinor = [-66, -54, -42, -30, -18, -6];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    // Two-tier grid via PlotChrome.
    for (final db in _gridDbMinor) {
      PlotChrome.drawVGrid(canvas, size, _xOfDb(db.toDouble(), size),
          color: ConsoleSkin.hairline);
      PlotChrome.drawHGrid(canvas, size, _yOfDb(db.toDouble(), size),
          color: ConsoleSkin.hairline);
    }
    for (final db in _gridDbMajor) {
      PlotChrome.drawVGrid(canvas, size, _xOfDb(db.toDouble(), size),
          color: ConsoleSkin.fgFaint);
      PlotChrome.drawHGrid(canvas, size, _yOfDb(db.toDouble(), size),
          color: ConsoleSkin.fgFaint);
    }

    // y=x reference.
    canvas.drawLine(
      Offset(_xOfDb(_dbFloor, size), _yOfDb(_dbFloor, size)),
      Offset(_xOfDb(_dbCeil, size), _yOfDb(_dbCeil, size)),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    final plot = PlotChrome.plotRect(size);
    if (points.isEmpty) {
      _drawText(
        canvas,
        'click anywhere to add an in/out point',
        Offset(plot.center.dx - 110, plot.center.dy - 6),
        ConsoleSkin.fgFaint,
      );
      _drawAxisLabels(canvas, size);
      return;
    }

    // Polyline through the points. Stretch first/last to the plot
    // edges so the visible curve fills the inner area.
    final path = Path();
    final firstY = _yOfDb(points.first.outDb, size);
    path.moveTo(plot.left, firstY);
    for (final p in points) {
      path.lineTo(_xOfDb(p.inDb, size), _yOfDb(p.outDb, size));
    }
    final lastY = _yOfDb(points.last.outDb, size);
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
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = _xOfDb(p.inDb, size);
      final y = _yOfDb(p.outDb, size);
      final hovered = i == hoveredIdx;
      final r = hovered ? 5.5 : 4.5;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = ConsoleSkin.accentHot);
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
    for (final db in _gridDbMajor) {
      PlotChrome.drawXLabel(
          canvas, size, _xOfDb(db.toDouble(), size), '$db');
      PlotChrome.drawYLabelRight(
          canvas, size, _yOfDb(db.toDouble(), size), '$db');
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: ConsoleSkin.fontMono,
      fontSize: ConsoleSkin.sizeTiny,
    ))
      ..pushStyle(ui.TextStyle(color: color, fontSize: ConsoleSkin.sizeTiny))
      ..addText(text);
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 240));
    canvas.drawParagraph(p, offset);
  }

  @override
  bool shouldRepaint(_CompandPainter old) =>
      old.points.length != points.length ||
      old.hoveredIdx != hoveredIdx ||
      _diff(old.points, points);

  bool _diff(List<CompandPoint> a, List<CompandPoint> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].inDb != b[i].inDb || a[i].outDb != b[i].outDb) return true;
    }
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────
// Controls — three knobs for the simple scalar parameters.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final CompandSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(CompandSettings next) {
    player.updateAudioEffects((b) => b.copyWith(compand: next));
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
            value: settings.gain,
            // Spec range -900..900 dB. Tighten to musical -36..+36 for
            // resolution.
            min: -36,
            max: 36,
            defaultValue: 0,
            onChanged: (v) => _apply(settings.copyWith(
              gain: v.clamp(CompandSettings.gainMin, CompandSettings.gainMax),
            )),
            label: 'gain dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.volume,
            // Spec -900..0; tighten to -60..0.
            min: -60,
            max: 0,
            defaultValue: 0,
            onChanged: (v) => _apply(settings.copyWith(
              volume: v.clamp(
                CompandSettings.volumeMin,
                CompandSettings.volumeMax,
              ),
            )),
            label: 'init vol',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.delay,
            min: CompandSettings.delayMin,
            max: 5,
            defaultValue: 0,
            onChanged: (v) => _apply(settings.copyWith(
              delay: v.clamp(
                CompandSettings.delayMin,
                CompandSettings.delayMax,
              ),
            )),
            label: 'delay s',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          // Soft-knee — typed access via [CompandSoftKneeX] (the
          // hyphen-named AVOption that lives in the `params` map).
          AtomKnob(
            value: settings.softKnee,
            min: 0,
            max: 24,
            defaultValue: kCompandSoftKneeDefault,
            onChanged: (v) => _apply(settings.withSoftKnee(v)),
            label: 'knee dB',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          // Attack / release of the FIRST envelope. Per-channel
          // envelopes would need a separate editor (consumer can
          // build them via [CompandEnvelopesX.withEnvelopes]); the
          // common case applies one envelope to every channel.
          AtomKnob(
            value: _firstEnvelopeAttackMs(settings),
            min: 0,
            max: 200,
            defaultValue: 0,
            onChanged: (ms) => _applyEnvelope(
              settings,
              attackSeconds: (ms / 1000).clamp(0, 60),
              decaySeconds: _firstEnvelopeDecayMs(settings) / 1000,
            ),
            label: 'atk ms',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _firstEnvelopeDecayMs(settings),
            min: 1,
            max: 2000,
            defaultValue: 800,
            onChanged: (ms) => _applyEnvelope(
              settings,
              attackSeconds: _firstEnvelopeAttackMs(settings) / 1000,
              decaySeconds: (ms / 1000).clamp(0, 60),
            ),
            label: 'rel ms',
            format: (v) => v.toStringAsFixed(0),
            size: 70,
          ),
        ],
      ),
    );
  }

  void _applyEnvelope(
    CompandSettings settings, {
    required double attackSeconds,
    required double decaySeconds,
  }) {
    _apply(settings.withEnvelopes([
      CompandEnvelope(
        attackSeconds: attackSeconds,
        decaySeconds: decaySeconds,
      ),
    ]));
  }
}

double _firstEnvelopeAttackMs(CompandSettings s) {
  final envs = s.envelopes;
  if (envs.isEmpty) return 0;
  return envs.first.attackSeconds * 1000;
}

double _firstEnvelopeDecayMs(CompandSettings s) {
  final envs = s.envelopes;
  if (envs.isEmpty) return 800;
  return envs.first.decaySeconds * 1000;
}
