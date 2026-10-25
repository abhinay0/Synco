import 'package:flutter/services.dart';

class ClipboardDetector {
  static String? _lastDetectedUrl;

  static final List<RegExp> supportedPatterns = [
    RegExp(r'https?://(?:www\.)?(?:youtube\.com|youtu\.be)/.+',
        caseSensitive: false),
    RegExp(r'https?://(?:www\.)?instagram\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?tiktok\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?(?:twitter|x)\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?(?:facebook\.com|fb\.watch)/.+',
        caseSensitive: false),
    RegExp(r'https?://(?:www\.)?reddit\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?soundcloud\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?vimeo\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?twitch\.tv/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?bilibili\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?threads\.net/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?dailymotion\.com/.+', caseSensitive: false),
    RegExp(r'https?://(?:www\.)?pinterest\.com/.+', caseSensitive: false),
  ];

  /// Tests whether a URL matches known video platforms or generic media web links
  static bool isRecognizedMediaUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    // Explicit platforms
    if (supportedPatterns.any((pattern) => pattern.hasMatch(trimmed))) {
      return true;
    }

    // General URL support: yt-dlp supports over 1,500 sites and direct media URLs
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority &&
        uri.host.contains('.')) {
      return true;
    }

    return false;
  }

  /// Check clipboard and return URL if valid and not already consumed
  static Future<String?> checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return null;

      if (text == _lastDetectedUrl) return null;

      if (isRecognizedMediaUrl(text)) {
        return text;
      }
    } catch (_) {}
    return null;
  }

  static void markAsHandled(String url) {
    _lastDetectedUrl = url;
  }

  static void reset() {
    _lastDetectedUrl = null;
  }
}
