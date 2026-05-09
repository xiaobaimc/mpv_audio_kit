import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_button.dart';
import '../atoms/atom_label.dart';
import '../atoms/atom_slider.dart';
import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';

/// Transport controls — seek lives inside [WaveformView] now (click on
/// the waveform to seek, vertical cursor = playhead).
///
/// Children are arranged as 4 micro-groups inside a [Wrap]: at desktop
/// widths everything stays on one line; when the bottom strip narrows,
/// groups reflow to a second/third line instead of overflowing.
class TransportBar extends StatelessWidget {
  const TransportBar({super.key});

  static String _fmt(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}'
          ':${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _gap() => const SizedBox(width: ConsoleSkin.gap);

  Widget _group(List<Widget> children) =>
      Row(mainAxisSize: MainAxisSize.min, children: children);

  @override
  Widget build(BuildContext context) {
    final player = StudioScope.of(context);

    // Transport buttons: round, all 28×28 except PLAY which is 40×40
    // (the only focal point on the row — every other control orbits it).
    const small = 28.0;
    const big   = 40.0;

    final transport = _group([
      AtomButton(
        label: 'PREV',
        icon: IconGlyph.prev,
        onTap: () => player.previous(),
        width: small,
        height: small,
        circular: true,
      ),
      _gap(),
      StreamBuilder<bool>(
        stream: player.stream.playing,
        builder: (ctx, snap) {
          final playing = snap.data ?? false;
          return AtomButton(
            label: playing ? 'PAUSE' : 'PLAY',
            icon: playing ? IconGlyph.pause : IconGlyph.play,
            toggled: playing,
            onTap: () => playing ? player.pause() : player.play(),
            width: big,
            height: big,
            circular: true,
          );
        },
      ),
      _gap(),
      AtomButton(
        label: 'STOP',
        icon: IconGlyph.stop,
        onTap: () => player.stop(),
        width: small,
        height: small,
        circular: true,
      ),
      _gap(),
      AtomButton(
        label: 'NEXT',
        icon: IconGlyph.next,
        onTap: () => player.next(),
        width: small,
        height: small,
        circular: true,
      ),
    ]);

    final modes = _group([
      StreamBuilder<Loop>(
        stream: player.stream.loop,
        builder: (ctx, snap) {
          final loop = snap.data ?? Loop.off;
          return AtomButton(
            label: 'LOOP',
            icon: IconGlyph.loop,
            toggled: loop != Loop.off,
            onTap: () => player.setLoop(
              loop == Loop.off ? Loop.playlist : Loop.off,
            ),
            width: small,
            height: small,
            circular: true,
          );
        },
      ),
      _gap(),
      StreamBuilder<bool>(
        stream: player.stream.shuffle,
        builder: (ctx, snap) {
          final shuf = snap.data ?? false;
          return AtomButton(
            label: 'SHUF',
            icon: IconGlyph.shuffle,
            toggled: shuf,
            onTap: () => player.setShuffle(!shuf),
            width: small,
            height: small,
            circular: true,
          );
        },
      ),
    ]);

    final time = StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (ctx, posSnap) => StreamBuilder<Duration>(
        stream: player.stream.duration,
        builder: (ctx, durSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = durSnap.data ?? Duration.zero;
          return AtomLabel(
            '${_fmt(pos)} / ${_fmt(dur)}',
            fontSize: ConsoleSkin.sizeSmall,
            color: ConsoleSkin.fgDim,
            mono: true,
          );
        },
      ),
    );

    final volume = _group([
      const AtomLabel(
        'VOL',
        fontSize: ConsoleSkin.sizeTiny,
        color: ConsoleSkin.fgDim,
        mono: true,
      ),
      _gap(),
      SizedBox(
        width: 100,
        child: StreamBuilder<double>(
          stream: player.stream.volume,
          builder: (ctx, snap) {
            final v = snap.data ?? 0;
            return AtomSlider(
              value: v,
              min: 0,
              max: 100,
              onChanged: (x) => player.setVolume(x),
            );
          },
        ),
      ),
    ]);

    // Time + volume sit together as one cluster so the time reads as
    // metadata of the volume strip, not as a free-floating third group.
    final timeAndVolume = _group([
      time,
      const SizedBox(width: ConsoleSkin.pad * 2),
      volume,
    ]);

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ConsoleSkin.pad * 2,
        runSpacing: 4,
        children: [transport, modes, timeAndVolume],
      ),
    );
  }
}
