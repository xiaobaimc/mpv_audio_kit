import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MpvAudioKit.ensureInitialized();
  runApp(const _App());
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      autoPlay: true,
      initialVolume: 50.0,
    ),
  );

  @override
  void initState() {
    super.initState();
    _player.open(Media(
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'mpv_audio_kit example',
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('mpv_audio_kit')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  initialData: false,
                  builder: (_, snap) => IconButton(
                    iconSize: 72,
                    onPressed: () => snap.data == true
                        ? _player.pause()
                        : _player.play(),
                    icon: Icon(snap.data == true
                        ? Icons.pause_circle
                        : Icons.play_circle),
                  ),
                ),
                const SizedBox(height: 24),
                StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  initialData: Duration.zero,
                  builder: (_, posSnap) => StreamBuilder<Duration>(
                    stream: _player.stream.duration,
                    initialData: Duration.zero,
                    builder: (_, durSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final dur = durSnap.data ?? Duration.zero;
                      return Column(children: [
                        Slider(
                          value: dur.inMilliseconds == 0
                              ? 0
                              : pos.inMilliseconds / dur.inMilliseconds,
                          onChanged: dur.inMilliseconds == 0
                              ? null
                              : (v) => _player.seek(Duration(
                                  milliseconds:
                                      (dur.inMilliseconds * v).round())),
                        ),
                        Text('${_fmt(pos)} / ${_fmt(dur)}',
                            style: const TextStyle(fontFamily: 'monospace')),
                      ]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

String _fmt(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
