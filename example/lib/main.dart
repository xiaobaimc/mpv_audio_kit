import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'shell/studio_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(360, 480),
        center: true,
        title: 'MPV STUDIO',
        backgroundColor: Color(0xFF1A1A1A),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  MpvAudioKit.ensureInitialized();

  final player = Player(
    configuration: const PlayerConfiguration(
      initialVolume: 60.0,
      autoPlay: true,
      logLevel: LogLevel.info,
    ),
  );

  runApp(StudioApp(player: player));
}
