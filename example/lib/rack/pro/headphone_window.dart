import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `headphone` (HRTF-based binaural
/// renderer). Hero element is a stylised **head + speaker ring** —
/// top-down view with N speakers positioned around the listener
/// (count derived from the channel `map`), indicating that the engine
/// is folding multi-channel content into a stereo headphone
/// presentation.
///
/// HRIR / SOFA file picking is out of scope for the headline UI —
/// `hrir` selects the rendering convention and stays at default. Two
/// knobs cover gain and LFE level.
class HeadphoneWindow extends StatelessWidget {
  final VoidCallback onClose;
  const HeadphoneWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final s = (snap.data ?? const AudioEffects()).headphone;
        return ProPluginWindow(
          filterName: 'headphone',
          onClose: onClose,
          graph: _Diagram(settings: s),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

class _Diagram extends StatelessWidget {
  final HeadphoneSettings settings;
  const _Diagram({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HeadPainter(channelMap: settings.map),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AtomLabel(
            settings.map.isEmpty ? '(default channel map)' : 'map: ${settings.map}',
            fontSize: ConsoleSkin.sizeTiny,
            color: ConsoleSkin.fgDim,
            mono: true,
          ),
        ],
      ),
    );
  }
}

class _HeadPainter extends CustomPainter {
  final String channelMap;
  _HeadPainter({required this.channelMap});

  // Standard layouts in degrees (0 = listener-front, +90 = right).
  static const Map<String, List<int>> _layouts = {
    'mono': [0],
    'stereo': [-30, 30],
    '5.1': [-30, 30, 0, 0, -110, 110],
    '7.1': [-30, 30, 0, 0, -90, 90, -150, 150],
  };

  List<int> _angles() {
    final m = channelMap.trim();
    if (m.isEmpty) return _layouts['stereo']!;
    return _layouts[m] ?? _layouts['stereo']!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.shortestSide / 2) - 18;

    // Speaker ring.
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = ConsoleSkin.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = true,
    );

    // Front indicator — small chevron above the ring.
    final fy = cy - r - 8;
    canvas.drawLine(
      Offset(cx - 6, fy + 6),
      Offset(cx, fy),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );
    canvas.drawLine(
      Offset(cx + 6, fy + 6),
      Offset(cx, fy),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    // Head — circle with two ear dots.
    final headRadius = r * 0.20;
    canvas.drawCircle(Offset(cx, cy), headRadius, Paint()..color = ConsoleSkin.bg);
    canvas.drawCircle(
      Offset(cx, cy),
      headRadius,
      Paint()
        ..color = ConsoleSkin.fg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      Offset(cx - headRadius, cy),
      2.5,
      Paint()..color = ConsoleSkin.fg,
    );
    canvas.drawCircle(
      Offset(cx + headRadius, cy),
      2.5,
      Paint()..color = ConsoleSkin.fg,
    );

    // Speakers — convert "0° = front" into screen radians where
    // -90° is the top of the canvas.
    for (final deg in _angles()) {
      final rad = (deg - 90) * math.pi / 180.0;
      final sx = cx + r * math.cos(rad);
      final sy = cy + r * math.sin(rad);
      canvas.drawCircle(Offset(sx, sy), 6, Paint()..color = ConsoleSkin.accent);
      canvas.drawCircle(
        Offset(sx, sy),
        6,
        Paint()
          ..color = ConsoleSkin.fg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_HeadPainter old) => old.channelMap != channelMap;
}

class _Controls extends StatelessWidget {
  final HeadphoneSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(HeadphoneSettings next) {
    player.updateAudioEffects((b) => b.copyWith(headphone: next));
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
            min: HeadphoneSettings.gainMin,
            max: HeadphoneSettings.gainMax,
            defaultValue: HeadphoneSettings.gainDefault,
            onChanged: (v) => _apply(settings.copyWith(gain: v)),
            label: 'gain dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.lfe,
            min: HeadphoneSettings.lfeMin,
            max: HeadphoneSettings.lfeMax,
            defaultValue: HeadphoneSettings.lfeDefault,
            onChanged: (v) => _apply(settings.copyWith(lfe: v)),
            label: 'lfe dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
        ],
      ),
    );
  }
}
