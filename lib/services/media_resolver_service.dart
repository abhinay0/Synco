import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/services/native_ytdlp_bridge.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

class MediaMetadataResult {
  final VideoInfo? videoInfo;
  final PlaylistInfo? playlistInfo;

  MediaMetadataResult({this.videoInfo, this.playlistInfo});
}

class MediaResolverService {
  static final yt_exp.YoutubeExplode _ytExplode = yt_exp.YoutubeExplode();

  /// Resolve metadata for any video or playlist URL across all platforms
  static Future<MediaMetadataResult> resolve(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      return MediaMetadataResult();
    }

    // 1. Android: use embedded youtubedl-android engine
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final jsonStr = await NativeYtDlpBridge.getInfo(cleanUrl);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (data['_type'] == 'playlist') {
            return MediaMetadataResult(
              playlistInfo: PlaylistInfo.fromJson(data),
            );
          } else {
            return MediaMetadataResult(
              videoInfo: VideoInfo.fromJson(data),
            );
          }
        }
      } catch (e) {
        debugPrint('MediaResolverService: Android native info failed: $e');
      }
    }

    // 2. Desktop: execute system yt-dlp with --dump-single-json
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      try {
        final env = _getEnvironmentWithToolPaths();
        final result = await Process.run(
          'yt-dlp',
          [
            cleanUrl,
            '--dump-single-json',
            '--socket-timeout',
            '10',
            '-R',
            '2',
            '--no-warnings',
          ],
          environment: env,
          runInShell: true,
        );

        if (result.exitCode == 0 &&
            result.stdout != null &&
            result.stdout.toString().isNotEmpty) {
          final data =
              jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
          if (data['_type'] == 'playlist') {
            return MediaMetadataResult(
              playlistInfo: PlaylistInfo.fromJson(data),
            );
          } else {
            return MediaMetadataResult(
              videoInfo: VideoInfo.fromJson(data),
            );
          }
        }
      } catch (e) {
        debugPrint('MediaResolverService: Desktop yt-dlp info failed: $e');
      }
    }

    // 3. Fallback: If YouTube URL, try youtube_explode_dart
    if (cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be')) {
      try {
        if (cleanUrl.contains('list=')) {
          final playlist = await _ytExplode.playlists.get(cleanUrl);
          return MediaMetadataResult(
            playlistInfo: PlaylistInfo(
              title: playlist.title,
              videoCount: 0,
              uploader: playlist.author,
              entries: [],
            ),
          );
        } else {
          final video = await _ytExplode.videos.get(cleanUrl);
          return MediaMetadataResult(
            videoInfo: VideoInfo(
              id: video.id.value,
              title: video.title,
              thumbnail: video.thumbnails.highResUrl,
              duration: video.duration?.toString() ?? '0:00',
              uploader: video.author,
              availableQualities: ['1080p', '720p', '480p', '360p'],
            ),
          );
        }
      } catch (e) {
        debugPrint('MediaResolverService: YoutubeExplode fallback failed: $e');
      }
    }

    // 4. Graceful placeholder fallback: allow direct download with chosen preset
    final uri = Uri.tryParse(cleanUrl);
    final host = uri?.host ?? 'Media Stream';
    return MediaMetadataResult(
      videoInfo: VideoInfo(
        id: cleanUrl.hashCode.toString(),
        title: cleanUrl,
        thumbnail: '',
        duration: 'Unknown',
        uploader: host,
        availableQualities: ['Best', '1080p', '720p', 'Audio Only'],
      ),
    );
  }

  static Map<String, String> _getEnvironmentWithToolPaths() {
    final env = Map<String, String>.from(Platform.environment);
    final additionalPaths = [
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
      if (Platform.environment['HOME'] != null)
        '${Platform.environment['HOME']}/.local/bin',
    ].join(':');

    final currentPath = env['PATH'] ?? '';
    env['PATH'] = '$additionalPaths:$currentPath';
    return env;
  }
}
