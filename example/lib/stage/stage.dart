import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_label.dart';
import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';
import 'waveform_view.dart';

/// Central column for the studio: a small title / AO-state header on
/// top, the rest filled by the full-track waveform (click = seek,
/// vertical cursor = playhead). The transport strip and FX rack live
/// outside the stage so the resize handle between them can grow the
/// rack without ever shrinking the waveform's chrome — the waveform
/// uses every pixel left over after the bottom panel takes its share.
class Stage extends StatelessWidget {
  /// Horizontal zoom factor for the waveform overview (1 = entire
  /// track visible; 2 = half; 4 = quarter; …). Centred on the playhead.
  final int zoomLevel;
  /// Allowed zoom range for the wheel-zoom shortcut (Cmd / Ctrl +
  /// wheel inside the waveform). Mirrors the toolbar buttons' bounds.
  final int zoomMin;
  final int zoomMax;
  /// Fired when the wheel-zoom shortcut changes [zoomLevel] so the
  /// owning shell can keep its state in sync.
  final ValueChanged<int>? onZoomChanged;

  const Stage({
    super.key,
    this.zoomLevel = 1,
    this.zoomMin = 1,
    this.zoomMax = 16,
    this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StageHeader(),
        const _Hairline(),
        Expanded(
          child: WaveformView(
            zoomLevel: zoomLevel,
            zoomMin: zoomMin,
            zoomMax: zoomMax,
            onZoomChanged: onZoomChanged,
          ),
        ),
      ],
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader();

  @override
  Widget build(BuildContext context) {
    final player = StudioScope.of(context);
    return SizedBox(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: StreamBuilder<String>(
                  stream: player.stream.mediaTitle,
                  builder: (ctx, snap) => AtomLabel(
                    snap.data?.isNotEmpty == true ? snap.data! : '',
                    fontSize: ConsoleSkin.sizeBody,
                    weight: FontWeight.w500,
                    color: ConsoleSkin.fg,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: StreamBuilder<AudioOutputState>(
                stream: player.stream.audioOutputState,
                builder: (ctx, snap) {
                  final s = snap.data ?? AudioOutputState.closed;
                  final color = switch (s) {
                    AudioOutputState.active => ConsoleSkin.meterGreen,
                    AudioOutputState.failed => ConsoleSkin.meterRed,
                    _ => ConsoleSkin.fgDim,
                  };
                  return AtomLabel(
                    'AO ${s.name.toUpperCase()}',
                    fontSize: ConsoleSkin.sizeTiny,
                    color: color,
                    mono: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Container(
        height: ConsoleSkin.hairlinePx,
        color: ConsoleSkin.hairline,
      );
}
