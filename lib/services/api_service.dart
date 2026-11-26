import 'dart:convert';

import 'package:http/http.dart' as http;

/// Web-safe HTTP client for communicating with an optional Synco backend API
/// (used on Web and as a fallback for non-YouTube URLs on Mobile).
class ApiService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8081',
  );

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = trimmed.isEmpty ? defaultBaseUrl : trimmed;
  }

  static Future<Map<String, dynamic>> getVideoInfo(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/video-info'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final error = _tryDecodeError(response.body);
      throw Exception(error ?? 'Failed to fetch video info (${response.statusCode})');
    } catch (e) {
      throw Exception('Error connecting to backend ($_baseUrl): $e');
    }
  }

  static Future<Map<String, dynamic>> getPlaylistInfo(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/playlist-info'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final error = _tryDecodeError(response.body);
      throw Exception(
        error ?? 'Failed to fetch playlist info (${response.statusCode})',
      );
    } catch (e) {
      throw Exception('Error connecting to backend ($_baseUrl): $e');
    }
  }

  static Future<Map<String, dynamic>> getDownloadUrl(
    String url, {
    String quality = '1080',
    bool isAudioOnly = false,
    String audioFormat = 'mp3',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/download-url'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'url': url,
              'quality': quality,
              'audioOnly': isAudioOnly,
              'audioFormat': audioFormat,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final error = _tryDecodeError(response.body);
      throw Exception(
        error ?? 'Failed to get download URL (${response.statusCode})',
      );
    } catch (e) {
      throw Exception('Error connecting to backend ($_baseUrl): $e');
    }
  }

  static Future<http.StreamedResponse> openDownloadStream(
    String url, {
    String quality = '1080',
    bool isAudioOnly = false,
    String audioFormat = 'mp3',
  }) async {
    final request = http.Request('POST', Uri.parse('$_baseUrl/api/download'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'url': url,
      'quality': quality,
      'audioOnly': isAudioOnly,
      'audioFormat': audioFormat,
    });
    final response = await request.send().timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('Backend download failed (HTTP ${response.statusCode})');
    }
    return response;
  }

  static Future<bool> checkHealth([String? overrideUrl]) async {
    final target = (overrideUrl ?? _baseUrl).trim().replaceAll(RegExp(r'/+$'), '');
    if (target.isEmpty) return false;
    try {
      final response = await http
          .get(Uri.parse('$target/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String? _tryDecodeError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return null;
  }
}
