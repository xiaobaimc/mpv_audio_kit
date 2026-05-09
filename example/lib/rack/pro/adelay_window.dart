import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_label.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_text_input.dart';
import '../../atoms/atom_toggle.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `adelay` (per-channel delay). Hero
/// element is a **per-channel timeline**: one row per parsed delay
/// in `delays`, each showing an impulse at `t=0` and an offset bar
/// at the channel's delay value. Reads at a glance "how staggered
/// the channels are", which is the whole point of `adelay`.
///
/// Channel markers are draggable horizontally to set per-channel
/// `delayMs`. Channel count is fixed by the audio layout, so the
/// graph supports drag only — no add/remove. The CSV field below
/// remains for sample-accurate or unit-suffixed input.
class AdelayWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AdelayWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).adelay;
        return ProPluginWindow(
          filterName: 'adelay',
          onClose: onClose,
          graph: _Timeline(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

// Channel delays are read / written through the lib-side
// [AdelayChannelsX] extension — the unit-suffix CSV grammar lives in
// `lib/src/types/settings/extensions/adelay_channels.dart`.

class _Timeline extends StatefulWidget {
  final AdelaySettings settings;
  final Player player;
  const _Timeline({required this.settings, required this.player});

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  int? _dragIdx;
  int? _hoverIdx;

  double _scaleFor(List<double> delays) {
    if (delays.isEmpty) return 1000;
    final maxDelay = delays.reduce((a, b) => a > b ? a : b);
    // Floor of 1000 ms keeps the axis usable even when all delays are
    // tiny; otherwise dragging would be hyper-sensitive.
    return (maxDelay * 1.1).clamp(1000.0, 60000.0);
  }

  double _xOfMs(double ms, Size size, double scale) {
    final plot = PlotChrome.plotRect(size);
    return plot.left + plot.width * (ms / scale);
  }

  double _msAt(double dx, Size size, double scale) {
    final plot = PlotChrome.plotRect(size);
    if (plot.width <= 0) return 0;
    final t = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (t * scale).clamp(0.0, scale);
  }

  int? _hitTest(Offset pos, Size size, {double tolerance = 10}) {
    final delays = widget.settings.channelDelaysMs;
    if (delays.isEmpty) return null;
    final plot = PlotChrome.plotRect(size);
    if (!plot.contains(pos)) return null;
    final scale = _scaleFor(delays);
    final rowH = plot.height / delays.length;
    // Determine which row we're in vertically.
    final rowIdx = ((pos.dy - plot.top) / rowH).floor();
    if (rowIdx < 0 || rowIdx >= delays.length) return null;
    final mx = _xOfMs(delays[rowIdx], size, scale);
    return (mx - pos.dx).abs() <= tolerance ? rowIdx : null;
  }

  void _writeDelays(List<double> next) {
    widget.player.updateAudioEffects(
      (b) => b.copyWith(adelay: widget.settings.withChannelDelaysMs(next)),
    );
  }

  void _onPanStart(DragStartDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    _dragIdx = hit;
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final i = _dragIdx;
    final delays = widget.settings.channelDelaysMs;
    if (i == null || i >= delays.length) return;
    final scale = _scaleFor(delays);
    final ms = _msAt(d.localPosition.dx, size, scale);
    final next = [...delays];
    next[i] = ms;
    _writeDelays(next);
  }

  void _onPanEnd(DragEndDetails _) {
    _dragIdx = null;
  }

  @override
  Widget build(BuildContext context) {
    final delays = widget.settings.channelDelaysMs;
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (delays.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: AtomLabel(
                  'add delays in the field below — one per channel, |-separated',
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgFaint,
                  mono: true,
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                return MouseRegion(
                  cursor: _hoverIdx != null
                      ? SystemMouseCursors.resizeLeftRight
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
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _ChannelsPainter(
                          delays: delays,
                          hoveredIdx: _hoverIdx,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelsPainter extends CustomPainter {
  final List<double> delays;
  final int? hoveredIdx;
  _ChannelsPainter({required this.delays, required this.hoveredIdx});

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);
    if (delays.isEmpty) return;

    final maxDelay = delays.reduce((a, b) => a > b ? a : b);
    final scale = (maxDelay * 1.1).clamp(1000.0, 60000.0);
    final rowH = plot.height / delays.length;
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

    for (var i = 0; i < delays.length; i++) {
      final yMid = plot.top + rowH * i + rowH / 2;
      if (i > 0) {
        PlotChrome.drawHGrid(canvas, size, plot.top + rowH * i);
      }
      // Impulse at t=0.
      canvas.drawRect(
        Rect.fromLTWH(plot.left, yMid - 6, 3, 12),
        Paint()..color = ConsoleSkin.fg,
      );
      // Delayed channel marker.
      final hovered = i == hoveredIdx;
      final x = xOfMs(delays[i]);
      final w = hovered ? 5.0 : 3.0;
      // Bar runs nearly the full row height when hovered, signalling
      // the drag handle.
      final barH = hovered ? rowH * 0.6 : 12.0;
      canvas.drawRect(
        Rect.fromLTWH(x - w / 2, yMid - barH / 2, w, barH),
        Paint()
          ..color = hovered ? ConsoleSkin.accentHot : ConsoleSkin.accent,
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
  bool shouldRepaint(_ChannelsPainter old) =>
      old.delays.length != delays.length ||
      old.hoveredIdx != hoveredIdx ||
      _delaysChanged(old.delays, delays);

  bool _delaysChanged(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }
}

class _Controls extends StatelessWidget {
  final AdelaySettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AdelaySettings next) {
    player.updateAudioEffects((b) => b.copyWith(adelay: next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Row(
            children: [
              AtomToggle(
                value: settings.all,
                onChanged: (v) => _apply(settings.copyWith(all: v)),
              ),
              const SizedBox(width: 6),
              const AtomLabel(
                'apply all',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                mono: true,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _CsvField(
              label: 'delays (ms, |-sep)',
              value: settings.delays,
              onChanged: (v) => _apply(settings.copyWith(delays: v)),
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
          width: 140,
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
