import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service for communicating with the Synco backend API
class ApiService {
  // Backend URL - update this with your deployed backend URL
  // For local testing: http://localhost:8081
  // For production: https://your-app.onrender.com
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8081',
  );

  /// Fetch video information from the backend
  static Future<Map<String, dynamic>> getVideoInfo(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/video-info'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch video info');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  /// Fetch playlist information from the backend
  static Future<Map<String, dynamic>> getPlaylistInfo(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/playlist-info'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch playlist info');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  /// Get the direct download URL for a video
  static Future<Map<String, dynamic>> getDownloadUrl(
    String url, {
    String quality = '1080',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/download-url'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url, 'quality': quality}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get download URL');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  /// Check if the backend is healthy and reachable
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Download video with progress tracking
  /// Returns a stream of download progress (0.0 to 1.0)
  static Stream<double> downloadVideo(
    String url,
    String filePath, {
    String quality = '1080',
  }) async* {
    try {
      // Create HTTP request
      final request = http.Request('POST', Uri.parse('$_baseUrl/api/download'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'url': url, 'quality': quality});

      // Send request and get stream
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Failed to download video: ${response.statusCode}');
      }

      // Get total file size from headers
      final contentLength = response.contentLength ?? 0;
      int bytesReceived = 0;

      // Open file for writing
      final file = File(filePath);
      final sink = file.openWrite();

      // Stream the response to file with progress updates
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        // Calculate and yield progress
        if (contentLength > 0) {
          final progress = bytesReceived / contentLength;
          yield progress;
        }
      }

      // Close the file
      await sink.close();

      // Yield 100% completion
      yield 1.0;
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }
}
