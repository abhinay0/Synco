import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synco/providers/app_state_provider.dart';
import 'package:synco/screens/home_screen.dart';
import 'package:synco/services/yt_dlp_service.dart';
import 'package:synco/utils/platform_utils.dart';
import 'package:synco/utils/theme.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize desktop window manager safely
  if (PlatformUtils.isDesktop) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1120, 740),
      minimumSize: Size(420, 620),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Synco',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final prefs = await SharedPreferences.getInstance();
  final appState = AppStateProvider(prefs);

  // Trigger background yt-dlp update check on Desktop without blocking startup
  if (PlatformUtils.isDesktop && appState.downloadService is YtDlpService) {
    unawaited((appState.downloadService as YtDlpService).checkAndUpdateYtDlp());
  }

  runApp(
    ChangeNotifierProvider<AppStateProvider>.value(
      value: appState,
      child: const SyncoApp(),
    ),
  );
}

class SyncoApp extends StatelessWidget {
  const SyncoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Synco',
          debugShowCheckedModeBanner: false,
          theme: SyncoTheme.lightTheme(appState.accentColor),
          darkTheme: SyncoTheme.darkTheme(appState.accentColor),
          themeMode: appState.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
