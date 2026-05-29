import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/home/home_page.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 800),
      minimumSize: Size(400, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  MpvAudioKit.ensureInitialized();
  // Example for custom libmpv path:
  // MpvAudioKit.ensureInitialized(libmpv: '/path/to/libmpv.so');
  final settingsService = await SettingsService.init();

  final player = Player(
    configuration: const PlayerConfiguration(
      initialVolume: 50.0,
      autoPlay: true,
      logLevel: LogLevel.debug,
    ),
  );

  // Enable the native OS media session — lockscreen / Control Center
  // entry on macOS, MPRIS on Linux, SMTC on Windows, MediaSession
  // notification on Android, lockscreen on iOS. Metadata (title /
  // artist / album / artwork / duration) is derived from mpv's own
  // properties; the consumer doesn't have to push anything. To
  // override individual fields, build a MediaSession with explicit
  // values: `MediaSession(title: 'My title', ...)`.
  await player.setMediaSession(const MediaSession());

  await settingsService.wire(player);

  runApp(
    MyApp(
      player: player,
      settingsService: settingsService,
    ),
  );
}

class MyApp extends StatefulWidget {
  final Player player;
  final SettingsService settingsService;

  const MyApp({
    super.key,
    required this.player,
    required this.settingsService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Root teardown. Consumers first (they observe the player), the
    // Player last. Player.dispose() releases the media session
    // automatically before tearing down libmpv. Fires only on process
    // teardown, but exercises the documented disposal path so this
    // example shows correct lifecycle.
    unawaited(widget.settingsService.dispose());
    unawaited(widget.player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mpv_audio_kit',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppTheme.scrollBehavior,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ExcludeSemantics(
        child: HomePage(
          player: widget.player,
          settingsService: widget.settingsService,
        ),
      ),
    );
  }
}
