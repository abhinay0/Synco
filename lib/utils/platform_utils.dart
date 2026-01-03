import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Utility class for platform-specific logic
class PlatformUtils {
  /// Check if the app should use local yt-dlp executable
  /// Returns true for desktop platforms (macOS, Windows, Linux)
  static bool get useLocalYtDlp {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// Check if the app should use the backend API
  /// Returns true for mobile platforms (iOS, Android) and web
  static bool get useBackendAPI {
    if (kIsWeb) return true;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Get the platform name for logging/debugging
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Check if platform supports local process execution
  static bool get supportsProcessExecution {
    return !kIsWeb && !Platform.isIOS && !Platform.isAndroid;
  }
}
