import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'shell/studio_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }

  MpvAudioKit.ensureInitialized();

  final player = Player(
    configuration: const PlayerConfiguration(
      initialVolume: 60.0,
      autoPlay: true,
      logLevel: LogLevel.debug,
    ),
  );

  runApp(StudioApp(player: player));
}
