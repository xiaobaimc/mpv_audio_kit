// A minimal mpv_audio_kit example: open a track and control playback.
//
// This is a deliberately tiny demo. The full feature showcase — DSP rack,
// queue, visualizers, per-platform settings — lives in the standalone
// MPV Studio app: https://github.com/ales-drnz/mpv_studio
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Registers the native libmpv backend. Call once before any Player.
  MpvAudioKit.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mpv_audio_kit example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const PlayerPage(),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _player = Player();
  final _uri = TextEditingController(
    text:
        'https://flutter.github.io/assets-for-api-docs/assets/audio/rooster.mp3',
  );
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void dispose() {
    _uri.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('mpv_audio_kit')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _uri,
                    decoration: const InputDecoration(
                      labelText: 'Audio URL or file path',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _player.open(Media(_uri.text), play: true),
                  child: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Currently playing title (from the file's tags, or its name).
            StreamBuilder<String>(
              stream: _player.stream.mediaTitle,
              builder: (_, s) => Text(
                s.data?.isNotEmpty == true ? s.data! : '—',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),

            // Seek bar — position and duration come off the player streams.
            StreamBuilder<Duration>(
              stream: _player.stream.duration,
              builder: (_, d) {
                _dur = d.data ?? _dur;
                return StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  builder: (_, p) {
                    _pos = p.data ?? _pos;
                    final max = _dur.inMilliseconds.toDouble();
                    final value =
                        _pos.inMilliseconds.clamp(0, _dur.inMilliseconds);
                    return Column(
                      children: [
                        Slider(
                          max: max <= 0 ? 1 : max,
                          value: max <= 0 ? 0 : value.toDouble(),
                          onChanged: max <= 0
                              ? null
                              : (v) => _player
                                  .seek(Duration(milliseconds: v.round())),
                        ),
                        Text('${_fmt(_pos)} / ${_fmt(_dur)}'),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Bind play/pause to the INTENT axis (playWhenReady) so the button
            // stays stable while the engine seeks or buffers.
            StreamBuilder<bool>(
              stream: _player.stream.playWhenReady,
              builder: (_, s) {
                final playing = s.data ?? false;
                return IconButton.filled(
                  iconSize: 48,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () =>
                      playing ? _player.pause() : _player.play(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}
