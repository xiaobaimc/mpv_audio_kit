import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_spectrum_curve.dart';
import '../skin/console_skin.dart';
import '../skin/paint_helpers.dart';

/// Bottom-right stage strip: live FFT envelope, drawn as a smooth
/// Catmull-Rom curve over a deep-bg framed canvas. Subscribes lazily;
/// the FFT pipeline runs only while this widget is mounted.
class SpectrumStrip extends StatefulWidget {
  final Player player;
  const SpectrumStrip({super.key, required this.player});

  @override
  State<SpectrumStrip> createState() => _SpectrumStripState();
}

class _SpectrumStripState extends State<SpectrumStrip> {
  Float32List? _bands;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FftFrame>(
      stream: widget.player.stream.fft,
      builder: (context, snap) {
        if (snap.hasData) _bands = snap.data!.bands;
        return CustomPaint(
          // Background frame: deep-bg fill + hairline border.
          painter: _StripFramePainter(),
          child: Padding(
            // Inset so the curve never touches the frame border.
            padding: const EdgeInsets.all(2),
            child: SpectrumCurve(
              bands: _bands ?? Float32List(0),
            ),
          ),
        );
      },
    );
  }
}

class _StripFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    box(
      canvas,
      Offset.zero & size,
      fill: ConsoleSkin.bgDeep,
      border: ConsoleSkin.hairline,
    );
  }

  @override
  bool shouldRepaint(covariant _StripFramePainter old) => false;
}
