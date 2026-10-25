import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'engine/download_engine.dart';
import 'screens/home_screen.dart';
import 'ui/theme/apple_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1040, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Synco v2 - Media Suite',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Load preferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => DownloadEngine()),
      ],
      child: const SyncoApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  ThemeProvider(this.prefs) {
    _loadFromPrefs();
  }

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = AppleTheme.systemBlue;
  String? _downloadPath;
  bool _incognitoMode = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  String? get downloadPath => _downloadPath;
  bool get incognitoMode => _incognitoMode;

  void _loadFromPrefs() {
    final isDark = prefs.getBool('isDark');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }

    final colorVal = prefs.getInt('accentColor');
    if (colorVal != null) {
      _accentColor = Color(colorVal);
    }

    _downloadPath = prefs.getString('downloadPath');
    _incognitoMode = prefs.getBool('incognitoMode') ?? false;
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    prefs.setInt('accentColor', color.toARGB32());
    notifyListeners();
  }

  void setDownloadPath(String path) {
    _downloadPath = path;
    prefs.setString('downloadPath', path);
    notifyListeners();
  }

  void toggleIncognito(bool value) {
    _incognitoMode = value;
    prefs.setBool('incognitoMode', value);
    notifyListeners();
  }
}

class SyncoApp extends StatelessWidget {
  const SyncoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Synco v2',
          debugShowCheckedModeBanner: false,
          theme: AppleTheme.lightTheme(accentColor: themeProvider.accentColor),
          darkTheme: AppleTheme.darkTheme(accentColor: themeProvider.accentColor),
          themeMode: themeProvider.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
