import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_text_input.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `aecho` (multi-tap echo). Hero
/// element is a **delay timeline** — the input transient lives at
/// `t=0` (left edge), and each tap fires at its `delay` offset with
/// height proportional to its `decay`. The timeline scales to the
/// longest tap automatically so a 1500 ms echo doesn't squash a
/// 30 ms slap-back into invisibility.
///
/// Taps are interactive on the timeline: click an empty area to add,
/// drag a tap to move it (horizontal = delay, vertical = decay),
/// right-click to remove. The CSV fields below remain for power-user
/// editing of large or sample-accurate configs.
class AechoWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AechoWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.aecho;
        return ProPluginWindow(
          filterName: 'aecho',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

// Taps are read / written through the lib-side [AechoTapsX]
// extension — the parallel-CSV grammar lives in
// `lib/src/types/settings/extensions/aecho_taps.dart`.

// ──────────────────────────────────────────────────────────────────────
// Graph — interactive delay timeline.
// ──────────────────────────────────────────────────────────────────────

// Tap delay floor / ceiling in the typed model. Decay is normalized to
// [0, 1].
const double _delayMin = 1;
const double _delayMaxFloor = 1000;
const double _decayMin = 0;
const double _decayMax = 1;

class _Graph extends StatefulWidget {
  final AechoSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  int? _dragIdx;
  int? _hoverIdx;

  // Visible scale (ms per plot width) — a function of the current taps
  // PLUS any in-flight drag, so dragging past the right edge expands
  // the axis instead of clipping.
  double _scaleFor(List<AechoTap> taps) {
    final maxMs = taps.isEmpty
        ? _delayMaxFloor
        : taps.map((t) => t.delayMs).reduce((a, b) => a > b ? a : b);
    return (maxMs * 1.1).clamp(50.0, 60000.0);
  }

  double _delayAt(double dx, Size size, double scale) {
    final plot = PlotChrome.plotRect(size);
    if (plot.width <= 0) return _delayMin;
    final t = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (t * scale).clamp(_delayMin, scale);
  }

  double _decayAt(double dy, Size size) {
    final plot = PlotChrome.plotRect(size);
    if (plot.height <= 0) return _decayMax;
    final mid = plot.top + plot.height / 2;
    // Half-plot above OR below midline maps to full decay; pick the
    // larger magnitude so dragging either way works.
    final dyAbs = (dy - mid).abs();
    final t = (dyAbs / (plot.height / 2)).clamp(0.0, 1.0);
    return (t * (_decayMax - _decayMin) + _decayMin)
        .clamp(_decayMin, _decayMax);
  }

  double _xOfMs(double ms, Size size, double scale) {
    final plot = PlotChrome.plotRect(size);
    return plot.left + plot.width * (ms / scale);
  }

  int? _hitTest(Offset pos, Size size, {double tolerance = 10}) {
    final taps = widget.settings.taps;
    final scale = _scaleFor(taps);
    final plot = PlotChrome.plotRect(size);
    if (!plot.contains(pos)) return null;
    var bestI = -1;
    var bestD = double.infinity;
    for (var i = 0; i < taps.length; i++) {
      final mx = _xOfMs(taps[i].delayMs, size, scale);
      // Bar runs full height of plot; only horizontal distance matters.
      final d = (mx - pos.dx).abs();
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    return bestD <= tolerance && bestI >= 0 ? bestI : null;
  }

  void _writeTaps(List<AechoTap> next) {
    widget.player.updateAudioEffects(
      (b) => b.copyWith(aecho: widget.settings.withTaps(next)),
    );
  }

  int _addTapAt(Offset pos, Size size) {
    final taps = widget.settings.taps;
    final scale = _scaleFor(taps);
    final delay = _delayAt(pos.dx, size, scale);
    final decay = _decayAt(pos.dy, size);
    final next = [
      ...taps,
      AechoTap(delayMs: delay, decay: decay),
    ];
    _writeTaps(next);
    return next.length - 1;
  }

  void _onTapDown(TapDownDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit == null) {
      _addTapAt(d.localPosition, size);
    }
  }

  void _onPanStart(DragStartDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit != null) {
      _dragIdx = hit;
    } else {
      _dragIdx = _addTapAt(d.localPosition, size);
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final i = _dragIdx;
    final taps = widget.settings.taps;
    if (i == null || i >= taps.length) return;
    final scale = _scaleFor(taps);
    final delay = _delayAt(d.localPosition.dx, size, scale);
    final decay = _decayAt(d.localPosition.dy, size);
    final next = [...taps];
    next[i] = next[i].copyWith(delayMs: delay, decay: decay);
    _writeTaps(next);
  }

  void _onPanEnd(DragEndDetails _) {
    _dragIdx = null;
  }

  void _onSecondaryTapDown(TapDownDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit == null) return;
    final next = [...widget.settings.taps]..removeAt(hit);
    _writeTaps(next);
  }

  @override
  Widget build(BuildContext context) {
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
                child: CustomPaint(
                  painter: _TimelinePainter(
                    taps: widget.settings.taps,
                    inGain: widget.settings.in_gain,
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

class _TimelinePainter extends CustomPainter {
  final List<AechoTap> taps;
  final double inGain;
  final int? hoveredIdx;
  _TimelinePainter({
    required this.taps,
    required this.inGain,
    required this.hoveredIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);

    final maxMs = taps.isEmpty
        ? _delayMaxFloor
        : taps.map((t) => t.delayMs).reduce((a, b) => a > b ? a : b);
    final scale = (maxMs * 1.1).clamp(50.0, 60000.0);
    final mid = plot.top + plot.height / 2;
    double xOfMs(double ms) => plot.left + plot.width * (ms / scale);

    double tick;
    if (scale <= 500) {
      tick = 100;
    } else if (scale <= 1500) {
      tick = 250;
    } else if (scale <= 5000) {
      tick = 500;
    } else {
      tick = 1000;
    }
    for (var t = tick; t < scale; t += tick) {
      PlotChrome.drawVGrid(canvas, size, xOfMs(t));
    }

    PlotChrome.drawHGrid(canvas, size, mid, color: ConsoleSkin.fgFaint);

    final dryHeight =
        (plot.height / 2) * inGain.clamp(0.0, 1.0).toDouble().clamp(0.2, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(plot.left, mid - dryHeight, 4, dryHeight * 2),
      Paint()..color = ConsoleSkin.fg,
    );

    for (var i = 0; i < taps.length; i++) {
      final t = taps[i];
      final x = xOfMs(t.delayMs);
      final h = (plot.height / 2) * t.decay.clamp(0.05, 1.0);
      final hovered = i == hoveredIdx;
      final w = hovered ? 5.0 : 3.0;
      canvas.drawRect(
        Rect.fromLTWH(x - w / 2, mid - h, w, h * 2),
        Paint()
          ..color = hovered ? ConsoleSkin.accentHot : ConsoleSkin.accent,
      );
      // Cap dot at the top end signals the marker handle.
      canvas.drawCircle(
        Offset(x, mid - h),
        hovered ? 4.0 : 3.0,
        Paint()
          ..color = hovered ? ConsoleSkin.fg : ConsoleSkin.fgDim,
      );
    }

    for (var t = tick; t < scale; t += tick) {
      final txt = t >= 1000
          ? '${(t / 1000).toStringAsFixed(t % 1000 == 0 ? 0 : 1)}s'
          : t.toStringAsFixed(0);
      PlotChrome.drawXLabel(canvas, size, xOfMs(t), txt);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.taps.length != taps.length ||
      old.inGain != inGain ||
      old.hoveredIdx != hoveredIdx ||
      _tapsChanged(old.taps, taps);

  bool _tapsChanged(List<AechoTap> a, List<AechoTap> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].delayMs != b[i].delayMs || a[i].decay != b[i].decay) {
        return true;
      }
    }
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────
// Controls — two knobs + two CSV text fields.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final AechoSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AechoSettings next) {
    player.updateAudioEffects((b) => b.copyWith(aecho: next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AtomKnob(
            value: settings.in_gain,
            min: AechoSettings.in_gainMin,
            max: AechoSettings.in_gainMax,
            defaultValue: AechoSettings.in_gainDefault,
            onChanged: (v) => _apply(settings.copyWith(in_gain: v)),
            label: 'in gain',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.out_gain,
            min: AechoSettings.out_gainMin,
            max: AechoSettings.out_gainMax,
            defaultValue: AechoSettings.out_gainDefault,
            onChanged: (v) => _apply(settings.copyWith(out_gain: v)),
            label: 'out gain',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 24),
          // CSV editors — one per axis. lavfi expects pipe-separated
          // values: '300|600|900' = three taps.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CsvField(
                  label: 'delays (ms, |-sep)',
                  value: settings.delays,
                  onChanged: (v) => _apply(settings.copyWith(delays: v)),
                ),
                const SizedBox(height: 6),
                _CsvField(
                  label: 'decays (0..1, |-sep)',
                  value: settings.decays,
                  onChanged: (v) => _apply(settings.copyWith(decays: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _CsvField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CsvField> createState() => _CsvFieldState();
}

class _CsvFieldState extends State<_CsvField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CsvField old) {
    super.didUpdateWidget(old);
    // If the upstream value changed (e.g. another widget mutated the
    // bundle), sync the controller — but only when the user isn't
    // mid-edit, so we don't yank the cursor out from under them.
    if (widget.value != old.value && widget.value != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: ConsoleSkin.fontMono,
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.fgDim,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AtomTextInput(
            controller: _ctrl,
            onSubmitted: widget.onChanged,
          ),
        ),
      ],
    );
  }
}
