import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/download_models.dart';
import 'media_resolver_service.dart';

class AppleMusicService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  static bool isAppleMusicUrl(String url) {
    return url.contains('music.apple.com');
  }

  /// Resolve metadata for Apple Music tracks, albums, and playlists
  static Future<MediaMetadataResult?> resolve(String url) async {
    try {
      final uri = Uri.parse(url.trim());
      final trackIdParam = uri.queryParameters['i'];

      // Extract album or item ID from path
      final pathSegments = uri.pathSegments;
      String? itemId;
      for (int i = pathSegments.length - 1; i >= 0; i--) {
        final seg = pathSegments[i];
        if (RegExp(r'^\d+$').hasMatch(seg)) {
          itemId = seg;
          break;
        }
      }

      final targetId = trackIdParam ?? itemId;

      if (targetId != null && targetId.isNotEmpty) {
        // Query iTunes Lookup API
        final lookupUrl = Uri.parse(
          'https://itunes.apple.com/lookup?id=$targetId&entity=song',
        );
        final res = await http.get(lookupUrl, headers: _headers).timeout(
              const Duration(seconds: 8),
            );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final count = data['resultCount'] as int? ?? 0;
          final results = (data['results'] as List?) ?? [];

          if (count > 0 && results.isNotEmpty) {
            // Case 1: Specific track requested via ?i=trackId
            if (trackIdParam != null) {
              final trackItem = results.firstWhere(
                (item) =>
                    item['trackId']?.toString() == trackIdParam ||
                    item['wrapperType'] == 'track',
                orElse: () => results.first,
              );

              final trackName = trackItem['trackName'] as String? ??
                  trackItem['collectionName'] as String? ??
                  'Apple Music Track';
              final artistName =
                  trackItem['artistName'] as String? ?? 'Apple Music Artist';
              final rawArtwork = trackItem['artworkUrl100'] as String? ?? '';
              final artwork = rawArtwork.replaceAll('100x100bb.jpg', '600x600bb.jpg');
              final millis = trackItem['trackTimeMillis'] as int? ?? 0;
              final durationStr = millis > 0
                  ? '${(millis ~/ 60000)}:${((millis % 60000) ~/ 1000).toString().padLeft(2, '0')}'
                  : 'Audio Track';

              return MediaMetadataResult(
                videoInfo: VideoInfo(
                  id: trackIdParam,
                  title: '$artistName - $trackName',
                  thumbnail: artwork,
                  duration: durationStr,
                  uploader: artistName,
                  availableQualities: ['Hi-Fi MP3 (320kbps)', 'M4A', 'FLAC', 'OPUS'],
                ),
              );
            }

            // Case 2: Entire Album / Collection
            final collectionItem = results.firstWhere(
              (item) => item['wrapperType'] == 'collection',
              orElse: () => results.first,
            );

            final collectionName =
                collectionItem['collectionName'] as String? ?? 'Apple Music Album';
            final artistName =
                collectionItem['artistName'] as String? ?? 'Apple Music Artist';
            final rawArtwork =
                collectionItem['artworkUrl100'] as String? ?? '';
            final artwork =
                rawArtwork.replaceAll('100x100bb.jpg', '600x600bb.jpg');

            final songItems =
                results.where((item) => item['wrapperType'] == 'track').toList();

            if (songItems.isNotEmpty) {
              final entries = songItems.map((s) {
                final sTrackName = s['trackName'] as String? ?? 'Track';
                final sArtist = s['artistName'] as String? ?? artistName;
                final sMillis = s['trackTimeMillis'] as int? ?? 0;
                final sDur = sMillis > 0
                    ? '${(sMillis ~/ 60000)}:${((sMillis % 60000) ~/ 1000).toString().padLeft(2, '0')}'
                    : 'Audio Track';

                return VideoInfo(
                  id: s['trackId']?.toString() ?? sTrackName.hashCode.toString(),
                  title: '$sArtist - $sTrackName',
                  thumbnail: artwork,
                  duration: sDur,
                  uploader: sArtist,
                  availableQualities: ['Hi-Fi MP3 (320kbps)', 'M4A', 'FLAC', 'OPUS'],
                );
              }).toList();

              return MediaMetadataResult(
                playlistInfo: PlaylistInfo(
                  title: '$artistName - $collectionName',
                  videoCount: entries.length,
                  uploader: artistName,
                  thumbnail: artwork,
                  entries: entries,
                ),
              );
            } else {
              // Single collection item
              return MediaMetadataResult(
                videoInfo: VideoInfo(
                  id: targetId,
                  title: '$artistName - $collectionName',
                  thumbnail: artwork,
                  duration: 'Audio Album',
                  uploader: artistName,
                  availableQualities: ['Hi-Fi MP3 (320kbps)', 'M4A', 'FLAC', 'OPUS'],
                ),
              );
            }
          }
        }
      }

      // Fallback: Web Scraping for Open Graph tags & title
      final pageRes = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 8),
          );
      if (pageRes.statusCode == 200) {
        final body = pageRes.body;

        final ogTitleMatch = RegExp(
          r'<meta\s+property=["' "'" r']og:title["' "'" r']\s+content=["' "'" r']([^"' "'" r']+)["' "'" r']',
          caseSensitive: false,
        ).firstMatch(body);

        final ogImageMatch = RegExp(
          r'<meta\s+property=["' "'" r']og:image["' "'" r']\s+content=["' "'" r']([^"' "'" r']+)["' "'" r']',
          caseSensitive: false,
        ).firstMatch(body);

        final titleMatch = RegExp(
          r'<title>(.*?)</title>',
          caseSensitive: false,
        ).firstMatch(body);

        var title = ogTitleMatch?.group(1) ??
            titleMatch?.group(1)?.replaceAll(' - Apple Music', '') ??
            'Apple Music Audio';
        title = title.replaceAll('&amp;', '&').trim();

        final artwork = ogImageMatch?.group(1) ?? '';

        return MediaMetadataResult(
          videoInfo: VideoInfo(
            id: url.hashCode.toString(),
            title: title,
            thumbnail: artwork,
            duration: 'Audio Track',
            uploader: 'Apple Music',
            availableQualities: ['Hi-Fi MP3 (320kbps)', 'M4A', 'FLAC', 'OPUS'],
          ),
        );
      }
    } catch (e) {
      debugPrint('AppleMusicService error: $e');
    }

    return null;
  }
}
