import 'package:flutter/services.dart';

class ClipboardDetector {
  static String? _lastDetectedUrl;

  static final List<RegExp> supportedPatterns = [
    RegExp(r'https?://(?:www\.)?(?:youtube\.com|youtu\.be)/.+'),
    RegExp(r'https?://(?:www\.)?instagram\.com/(?:p|reel|tv)/.+'),
    RegExp(r'https?://(?:www\.)?tiktok\.com/.+'),
    RegExp(r'https?://(?:www\.)?(?:twitter|x)\.com/.+/status/.+'),
    RegExp(r'https?://(?:www\.)?reddit\.com/r/.+/comments/.+'),
    RegExp(r'https?://(?:www\.)?soundcloud\.com/.+'),
    RegExp(r'https?://(?:www\.)?vimeo\.com/.+'),
  ];

  /// Check clipboard and return URL if valid and not already consumed
  static Future<String?> checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return null;

      if (text == _lastDetectedUrl) return null;

      final isMatch = supportedPatterns.any((pattern) => pattern.hasMatch(text));
      if (isMatch) {
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
