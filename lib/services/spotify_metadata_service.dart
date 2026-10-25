import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/download_models.dart';
import 'media_resolver_service.dart';

class SpotifyMetadataService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  static bool isSpotifyUrl(String url) {
    return url.contains('spotify.com/track/') ||
        url.contains('spotify.com/playlist/') ||
        url.contains('spotify.com/album/') ||
        url.contains('spotify.com/artist/');
  }

  /// Resolve metadata for Spotify tracks and playlists via public embed hydration
  static Future<MediaMetadataResult?> resolve(String url) async {
    try {
      final cleanUrl = url.trim();

      if (cleanUrl.contains('/track/')) {
        return await _resolveTrack(cleanUrl);
      } else if (cleanUrl.contains('/playlist/') ||
          cleanUrl.contains('/album/')) {
        return await _resolvePlaylistOrAlbum(cleanUrl);
      }
    } catch (e) {
      debugPrint('SpotifyMetadataService error: $e');
    }
    return null;
  }

  static Future<MediaMetadataResult?> _resolveTrack(String url) async {
    // 1. Try oEmbed for instantaneous single track title and album art
    try {
      final oembedUrl = Uri.parse(
          'https://open.spotify.com/oembed?url=${Uri.encodeComponent(url)}');
      final res = await http
          .get(oembedUrl, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final title = data['title'] as String? ?? 'Spotify Track';
        final thumbnail = data['thumbnail_url'] as String? ?? '';

        return MediaMetadataResult(
          videoInfo: VideoInfo(
            id: url.hashCode.toString(),
            title: title,
            thumbnail: thumbnail,
            duration: 'Audio Track',
            uploader: 'Spotify Artist',
            availableQualities: ['Hi-Fi MP3', 'M4A', 'FLAC', 'OPUS'],
          ),
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<MediaMetadataResult?> _resolvePlaylistOrAlbum(
      String url) async {
    try {
      // Use embed page which includes server-rendered __NEXT_DATA__ JSON hydration
      final embedUrl =
          url.replaceAll('open.spotify.com/', 'open.spotify.com/embed/');
      final res = await http
          .get(Uri.parse(embedUrl), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final match = RegExp(
          r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
          dotAll: true,
        ).firstMatch(res.body);

        if (match != null) {
          final jsonStr = match.group(1);
          if (jsonStr != null) {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final entity = data['props']?['pageProps']?['state']?['data']
                ?['entity'] as Map<String, dynamic>?;

            if (entity != null) {
              final title = entity['title'] as String? ??
                  entity['name'] as String? ??
                  'Spotify Playlist';
              final uploader = entity['subtitle'] as String? ?? 'Spotify';
              final coverArt =
                  entity['coverArt']?['sources']?[0]?['url'] as String? ?? '';
              final trackList = entity['trackList'] as List? ?? [];

              final entries = trackList.map((t) {
                final trackTitle = t['title'] as String? ?? 'Unknown Track';
                final trackArtist = t['subtitle'] as String? ?? '';
                final fullTitle = trackArtist.isNotEmpty
                    ? '$trackArtist - $trackTitle'
                    : trackTitle;
                final durationMs = (t['duration'] as num?)?.toInt() ?? 0;
                final durationStr = durationMs > 0
                    ? '${(durationMs ~/ 60000)}:${((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0')}'
                    : 'Audio Track';

                return VideoInfo(
                  id: t['uri'] ?? fullTitle.hashCode.toString(),
                  title: fullTitle,
                  thumbnail: coverArt,
                  duration: durationStr,
                  uploader: trackArtist.isNotEmpty ? trackArtist : uploader,
                  availableQualities: ['Hi-Fi MP3', 'M4A', 'FLAC', 'OPUS'],
                );
              }).toList();

              return MediaMetadataResult(
                playlistInfo: PlaylistInfo(
                  title: title,
                  videoCount: entries.length,
                  uploader: uploader,
                  thumbnail: coverArt,
                  entries: entries,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify playlist resolution error: $e');
    }
    return null;
  }
}
