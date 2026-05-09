import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_text_input.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `chorus`. Unlike the other
/// modulation filters, `chorus` is multi-voice — it takes parallel
/// `delays`, `decays`, `speeds`, `depths` strings (`|`-separated)
/// each yielding one detuned voice mixed back into the dry. Hero
/// element is a **voice grid**: each voice as a dot at
/// `(delay, depth)` with size scaled to its decay; the whole grid
/// reads as "X voices fanning out from the source".
///
/// Voices are interactive: click empty area to add a voice with
/// sensible defaults, drag to move (horizontal = delay, vertical =
/// depth), right-click to remove. CSV editors below remain for
/// per-voice tuning of decay and speed.
class ChorusWindow extends StatelessWidget {
  final VoidCallback onClose;
  const ChorusWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).chorus;
        return ProPluginWindow(
          filterName: 'chorus',
          onClose: onClose,
          graph: _VoiceGrid(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

// Voices are read / written through the lib-side [ChorusVoicesX]
// extension — the four parallel-CSV grammar lives in
// `lib/src/types/settings/extensions/chorus_voices.dart`.

const double _maxDelay = 120.0;
const double _maxDepth = 3.0;
const double _defaultDecay = 0.5;
const double _defaultSpeed = 0.5;

class _VoiceGrid extends StatefulWidget {
  final ChorusSettings settings;
  final Player player;
  const _VoiceGrid({required this.settings, required this.player});

  @override
  State<_VoiceGrid> createState() => _VoiceGridState();
}

class _VoiceGridState extends State<_VoiceGrid> {
  int? _dragIdx;
  int? _hoverIdx;

  double _delayAt(double dx, Size size) {
    final plot = PlotChrome.plotRect(size);
    if (plot.width <= 0) return 0;
    final t = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (t * _maxDelay).clamp(0.0, _maxDelay);
  }

  double _depthAt(double dy, Size size) {
    final plot = PlotChrome.plotRect(size);
    if (plot.height <= 0) return 0;
    final mid = plot.top + plot.height / 2;
    final dyAbs = (dy - mid).abs();
    final t = (dyAbs / (plot.height / 2)).clamp(0.0, 1.0);
    return (t * _maxDepth).clamp(0.0, _maxDepth);
  }

  double _xOfMs(double ms, Size size) {
    final plot = PlotChrome.plotRect(size);
    return plot.left + plot.width * (ms.clamp(0.0, _maxDelay) / _maxDelay);
  }

  // Depth-mid-spread band centre (always plot mid).
  double _midOf(Size size) {
    final plot = PlotChrome.plotRect(size);
    return plot.top + plot.height / 2;
  }

  int? _hitTest(Offset pos, Size size, {double tolerance = 12}) {
    final voices = widget.settings.voices;
    final plot = PlotChrome.plotRect(size);
    if (!plot.contains(pos)) return null;
    final mid = _midOf(size);
    var bestI = -1;
    var bestD = double.infinity;
    for (var i = 0; i < voices.length; i++) {
      final v = voices[i];
      final mx = _xOfMs(v.delayMs, size);
      // Voice has a vertical span equal to depth on either side of mid;
      // the user can grab anywhere along that span.
      final span = (plot.height / 2) *
          (v.depthMs.clamp(0.0, _maxDepth) / _maxDepth);
      final dy = pos.dy - mid;
      final dyClamped = dy.abs() <= span ? 0.0 : (dy.abs() - span);
      final d = (Offset(mx, 0) - Offset(pos.dx, 0)).distance + dyClamped;
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    return bestD <= tolerance && bestI >= 0 ? bestI : null;
  }

  void _writeVoices(List<ChorusVoice> next) {
    widget.player.updateAudioEffects(
      (b) => b.copyWith(chorus: widget.settings.withVoices(next)),
    );
  }

  int _addVoiceAt(Offset pos, Size size) {
    final voices = widget.settings.voices;
    final delay = _delayAt(pos.dx, size);
    final depth = _depthAt(pos.dy, size);
    final next = [
      ...voices,
      ChorusVoice(
        delayMs: delay,
        decay: _defaultDecay,
        depthMs: depth,
        speedHz: _defaultSpeed,
      ),
    ];
    _writeVoices(next);
    return next.length - 1;
  }

  void _onTapDown(TapDownDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit == null) {
      _addVoiceAt(d.localPosition, size);
    }
  }

  void _onPanStart(DragStartDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit != null) {
      _dragIdx = hit;
    } else {
      _dragIdx = _addVoiceAt(d.localPosition, size);
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final i = _dragIdx;
    final voices = widget.settings.voices;
    if (i == null || i >= voices.length) return;
    final delay = _delayAt(d.localPosition.dx, size);
    final depth = _depthAt(d.localPosition.dy, size);
    final next = [...voices];
    next[i] = next[i].copyWith(delayMs: delay, depthMs: depth);
    _writeVoices(next);
  }

  void _onPanEnd(DragEndDetails _) {
    _dragIdx = null;
  }

  void _onSecondaryTapDown(TapDownDetails d, Size size) {
    final hit = _hitTest(d.localPosition, size);
    if (hit == null) return;
    final next = [...widget.settings.voices]..removeAt(hit);
    _writeVoices(next);
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
                  painter: _VoicePainter(
                    voices: widget.settings.voices,
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

class _VoicePainter extends CustomPainter {
  final List<ChorusVoice> voices;
  final int? hoveredIdx;
  _VoicePainter({required this.voices, required this.hoveredIdx});

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);

    final mid = plot.top + plot.height / 2;
    double xOfMs(double ms) =>
        plot.left + plot.width * (ms.clamp(0.0, _maxDelay) / _maxDelay);

    PlotChrome.drawHGrid(canvas, size, mid, color: ConsoleSkin.fgFaint);

    for (var d = 20.0; d < _maxDelay; d += 20) {
      PlotChrome.drawVGrid(canvas, size, xOfMs(d));
    }

    canvas.drawRect(
      Rect.fromLTWH(plot.left, mid - 8, 3, 16),
      Paint()..color = ConsoleSkin.fg,
    );

    for (var i = 0; i < voices.length; i++) {
      final v = voices[i];
      final x = xOfMs(v.delayMs);
      final span =
          (plot.height / 2) * (v.depthMs.clamp(0.0, _maxDepth) / _maxDepth);
      final hovered = i == hoveredIdx;
      final size2 = (3 + 6 * v.decay.clamp(0.0, 1.0)) + (hovered ? 2.0 : 0.0);
      canvas.drawRect(
        Rect.fromLTRB(x - 1.5, mid - span, x + 1.5, mid + span),
        Paint()
          ..color = (hovered ? ConsoleSkin.accentHot : ConsoleSkin.accent)
              .withValues(alpha: hovered ? 0.55 : 0.4),
      );
      canvas.drawCircle(
        Offset(x, mid),
        size2,
        Paint()..color = hovered ? ConsoleSkin.accentHot : ConsoleSkin.accent,
      );
      if (hovered) {
        canvas.drawCircle(
          Offset(x, mid),
          size2,
          Paint()
            ..color = ConsoleSkin.fg
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    for (var d = 20.0; d <= _maxDelay; d += 20) {
      PlotChrome.drawXLabel(canvas, size, xOfMs(d), d.toStringAsFixed(0));
    }
  }

  @override
  bool shouldRepaint(_VoicePainter old) =>
      old.voices.length != voices.length ||
      old.hoveredIdx != hoveredIdx ||
      _voicesChanged(old.voices, voices);

  bool _voicesChanged(List<ChorusVoice> a, List<ChorusVoice> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }
}

class _Controls extends StatelessWidget {
  final ChorusSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(ChorusSettings next) {
    player.updateAudioEffects((b) => b.copyWith(chorus: next));
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
            min: ChorusSettings.in_gainMin,
            max: ChorusSettings.in_gainMax,
            defaultValue: ChorusSettings.in_gainDefault,
            onChanged: (v) => _apply(settings.copyWith(in_gain: v)),
            label: 'in gain',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.out_gain,
            min: ChorusSettings.out_gainMin,
            max: ChorusSettings.out_gainMax,
            defaultValue: ChorusSettings.out_gainDefault,
            onChanged: (v) => _apply(settings.copyWith(out_gain: v)),
            label: 'out gain',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _CsvField(
                  label: 'delays (ms)',
                  value: settings.delays,
                  onChanged: (v) => _apply(settings.copyWith(delays: v)),
                ),
                const SizedBox(height: 4),
                _CsvField(
                  label: 'decays',
                  value: settings.decays,
                  onChanged: (v) => _apply(settings.copyWith(decays: v)),
                ),
                const SizedBox(height: 4),
                _CsvField(
                  label: 'speeds (Hz)',
                  value: settings.speeds,
                  onChanged: (v) => _apply(settings.copyWith(speeds: v)),
                ),
                const SizedBox(height: 4),
                _CsvField(
                  label: 'depths (ms)',
                  value: settings.depths,
                  onChanged: (v) => _apply(settings.copyWith(depths: v)),
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
          width: 100,
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
