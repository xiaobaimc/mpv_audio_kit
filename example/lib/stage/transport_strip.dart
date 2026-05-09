import 'package:flutter/widgets.dart';

import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';
import 'artwork_thumb.dart';
import 'spectrum_strip.dart';
import 'transport_bar.dart';

/// Fixed-height row at the foot of the central column: artwork thumb
/// on the left, transport (prev/play/stop/next + modes + time + vol)
/// in the middle, mini spectrum on the right. Lives between the stage
/// (waveform area) and the FX rack so the resize handle can sit above
/// it and grow / shrink the rack without ever touching the transport.
class TransportStrip extends StatelessWidget {
  const TransportStrip({super.key});

  static const double height = 96;

  @override
  Widget build(BuildContext context) {
    final player = StudioScope.of(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(ConsoleSkin.pad),
        child: Row(
          children: [
            ArtworkThumb(player: player),
            const SizedBox(width: ConsoleSkin.pad * 2),
            const Expanded(child: TransportBar()),
            const SizedBox(width: ConsoleSkin.pad * 2),
            SizedBox(
              width: 200,
              child: SpectrumStrip(player: player),
            ),
          ],
        ),
      ),
    );
  }
}
