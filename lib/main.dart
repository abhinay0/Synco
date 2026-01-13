import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:synco/utils/theme.dart';
import 'package:synco/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 700),
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

  // Load preferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(prefs),
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
  Color _accentColor = const Color(0xFF6366F1); // Default Purple/Indigo
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
          title: 'Synco',
          debugShowCheckedModeBanner: false,
          theme: SyncoTheme.lightTheme(themeProvider.accentColor),
          darkTheme: SyncoTheme.darkTheme(themeProvider.accentColor),
          themeMode: themeProvider.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
