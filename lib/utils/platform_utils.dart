import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Cross-platform utilities that remain 100% Web-safe.
class PlatformUtils {
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get useLocalYtDlp => isDesktop;

  static bool get useBackendAPI => kIsWeb;

  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  static bool get supportsProcessExecution => isDesktop;

  /// Resolves a safe, writable default base download directory on every OS.
  static Future<String> resolveDefaultDownloadDirectory() async {
    if (kIsWeb) return 'Browser Downloads';

    if (Platform.isAndroid) {
      const publicDownloads = '/storage/emulated/0/Download';
      try {
        final dir = Directory(publicDownloads);
        if (await dir.exists()) {
          return publicDownloads;
        }
      } catch (_) {
        // Fallback below if scoped storage blocks direct probe
      }
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return extDir.path;
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    }

    if (Platform.isIOS) {
      final docDir = await getApplicationDocumentsDirectory();
      return docDir.path;
    }

    // Desktop (macOS / Windows / Linux)
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir.path;
    } catch (_) {
      // Fallback to environment variables
    }

    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      final sep = Platform.isWindows ? r'\' : '/';
      return '$home${sep}Downloads';
    }

    final docDir = await getApplicationDocumentsDirectory();
    return docDir.path;
  }

  /// Ensures the target directory exists, falling back cleanly if restricted.
  static Future<String> prepareOutputDirectory({
    required String? customBasePath,
    required bool autoCreateSubfolders,
    String? collectionName,
    bool isChannel = false,
  }) async {
    if (kIsWeb) return 'Browser Downloads';

    final sep = Platform.isWindows ? r'\' : '/';
    String base = (customBasePath != null && customBasePath.trim().isNotEmpty)
        ? customBasePath.trim()
        : await resolveDefaultDownloadDirectory();

    if (base.endsWith('/') || base.endsWith(r'\')) {
      base = base.substring(0, base.length - 1);
    }

    String target = '$base${sep}Synco';
    if (autoCreateSubfolders &&
        collectionName != null &&
        collectionName.trim().isNotEmpty) {
      final safeFolder = sanitizeFilename(collectionName);
      final category = isChannel ? 'Channels' : 'Playlists';
      target = '$target$sep$category$sep$safeFolder';
    }

    try {
      final dir = Directory(target);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } catch (_) {
      // Fallback to app-private directory (e.g., Android scoped storage denial)
      final fallbackBase =
          (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
          await getApplicationDocumentsDirectory();
      String fallbackTarget = '${fallbackBase.path}${sep}Synco';
      if (autoCreateSubfolders &&
          collectionName != null &&
          collectionName.trim().isNotEmpty) {
        fallbackTarget = '$fallbackTarget$sep${sanitizeFilename(collectionName)}';
      }
      final fallbackDir = Directory(fallbackTarget);
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackDir.path;
    }
  }

  static String sanitizeFilename(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'Synco_Media';
    return cleaned.length > 90 ? cleaned.substring(0, 90).trim() : cleaned;
  }

  static Future<bool> openLocalPath(String path) async {
    if (kIsWeb || path.isEmpty) return false;
    try {
      final result = await OpenFile.open(path);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
