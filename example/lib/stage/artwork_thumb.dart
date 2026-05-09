import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../skin/console_skin.dart';
import '../skin/paint_helpers.dart';

/// Square cover-art thumbnail. `null` cover paints a `bgDeep` placeholder
/// with a hairline border.
class ArtworkThumb extends StatefulWidget {
  final Player player;
  final double size;
  const ArtworkThumb({super.key, required this.player, this.size = 80});

  @override
  State<ArtworkThumb> createState() => _ArtworkThumbState();
}

class _ArtworkThumbState extends State<ArtworkThumb> {
  CoverArt? _cover;
  StreamSubscription<CoverArt?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.player.stream.coverArt.listen((c) {
      if (mounted) setState(() => _cover = c);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _cover;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: c != null
          ? RepaintBoundary(
              child: Image.memory(
                c.bytes,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ),
            )
          : CustomPaint(painter: _PlaceholderPainter()),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    box(canvas, Offset.zero & size,
        fill: ConsoleSkin.bgDeep, border: ConsoleSkin.hairline);
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) => false;
}
