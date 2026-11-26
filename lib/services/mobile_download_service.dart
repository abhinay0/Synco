import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/services/api_service.dart';
import 'package:synco/services/download_service.dart';
import 'package:synco/services/url_resolver_service.dart';
import 'package:synco/utils/platform_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MobileDownloadService implements DownloadService {
  final YoutubeExplode _yt = YoutubeExplode();
  bool _isDownloading = false;
  bool _cancelRequested = false;

  @override
  bool get isDownloading => _isDownloading;

  @override
  void updateConfig({
    String? cookiesBrowser,
    String? cookiesFilePath,
    String? backendUrl,
  }) {
    if (backendUrl != null) ApiService.setBaseUrl(backendUrl);
  }

  @override
  void cancelCurrentDownload() {
    _cancelRequested = true;
    _isDownloading = false;
  }

  @override
  Future<EngineDiagnostics> checkDiagnostics() async {
    final backendOk = await ApiService.checkHealth();
    return EngineDiagnostics(
      ytDlpAvailable: true,
      ytDlpVersion: 'Built-in Mobile Engine (YouTube + Music Resolver)',
      ffmpegAvailable: false,
      jsRuntimeName: 'Native Client Fallback (Android VR / TV)',
      jsRuntimePath: 'Built-in',
      backendReachable: backendOk,
      platformLabel: PlatformUtils.platformName,
    );
  }

  @override
  Future<String> updateEngine() async {
    return 'Mobile engine uses built-in multi-client YouTube extraction. Keep Synco updated for latest client patches.';
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      debugPrint('Synco: Permission request warning: $e');
    }
  }

  /// Resilient manifest fetching that bypasses YouTube's SABR / iOS client
  /// restrictions by trying Android VR, Android SDK-less, TV, and Safari clients.
  Future<StreamManifest> _getManifestResilient(VideoId videoId) async {
    final clientBatches = <List<YoutubeApiClient>>[
      [YoutubeApiClient.androidVr, YoutubeApiClient.androidSdkless],
      [YoutubeApiClient.tv, YoutubeApiClient.safari],
      [YoutubeApiClient.ios],
    ];

    Object? lastError;
    for (final clients in clientBatches) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: clients,
          requireWatchPage: false,
        );
        if (manifest.streams.isNotEmpty) {
          return manifest;
        }
      } catch (e) {
        lastError = e;
        debugPrint('Synco Mobile: Client batch failed ($clients): $e');
      }
    }

    throw Exception(
      'YouTube SABR/client restriction prevented fetching streams: $lastError',
    );
  }

  /// Resolves Spotify / Apple Music / Amazon Music / plain text search into a
  /// matching YouTube Video using built-in search.
  Future<({Video video, ResolvedMusicTrack? resolvedTrack})>
  _resolveYouTubeVideo(String url, {ParsedMediaInput? parsed}) async {
    final effective = parsed ?? UrlResolverService.parseInput(url);
    if (!effective.isValid) {
      throw Exception('Could not extract a valid URL from "$url"');
    }

    if (effective.requiresMusicSearchResolution) {
      final track = await UrlResolverService.resolveMusicTrack(effective);
      final query = track?.searchQuery ?? effective.searchHint ?? effective.cleanUrl;
      final results = await _yt.search.search(query);
      if (results.isEmpty) {
        throw Exception('No matching audio found on YouTube for "$query"');
      }
      return (video: results.first, resolvedTrack: track);
    }

    final video = await _yt.videos.get(effective.cleanUrl);
    return (video: video, resolvedTrack: null);
  }

  @override
  Future<VideoInfo> getVideoInfo(String url, {ParsedMediaInput? parsed}) async {
    final effective = parsed ?? UrlResolverService.parseInput(url);
    if (!effective.isValid) {
      throw Exception('Could not extract a valid URL from "$url"');
    }

    // Non-YouTube, non-DRM-music URLs (Instagram, TikTok, Reddit, SoundCloud, etc.)
    // route through the optional Synco backend server on mobile.
    if (!effective.platform.isYouTubeFamily &&
        !effective.requiresMusicSearchResolution) {
      final json = await ApiService.getVideoInfo(effective.cleanUrl);
      return VideoInfo.fromJson(json, platform: effective.platform);
    }

    final resolved = await _resolveYouTubeVideo(url, parsed: effective);
    final video = resolved.video;
    final manifest = await _getManifestResilient(video.id);

    final Set<String> qualities = {};
    for (final s in manifest.muxed) {
      qualities.add('${s.videoResolution.height}p');
    }
    for (final s in manifest.videoOnly) {
      qualities.add('${s.videoResolution.height}p');
    }

    final sortedQualities = qualities.toList()
      ..sort((a, b) {
        final hA = int.tryParse(a.replaceAll('p', '')) ?? 0;
        final hB = int.tryParse(b.replaceAll('p', '')) ?? 0;
        return hB.compareTo(hA);
      });

    return VideoInfo(
      id: video.id.value,
      title: resolved.resolvedTrack?.title.isNotEmpty == true
          ? resolved.resolvedTrack!.title
          : video.title,
      thumbnail: resolved.resolvedTrack?.thumbnail.isNotEmpty == true
          ? resolved.resolvedTrack!.thumbnail
          : video.thumbnails.highResUrl,
      duration: VideoInfo.formatDurationSeconds(video.duration?.inSeconds ?? 0),
      uploader: resolved.resolvedTrack?.sourceLabel ?? video.author,
      url: video.url,
      platform: effective.platform,
      availableQualities: sortedQualities,
    );
  }

  @override
  Future<PlaylistInfo> getPlaylistInfo(
    String url, {
    ParsedMediaInput? parsed,
  }) async {
    final effective = parsed ?? UrlResolverService.parseInput(url);
    if (!effective.isValid) {
      throw Exception('Could not extract a valid URL from "$url"');
    }

    if (!effective.platform.isYouTubeFamily) {
      final json = await ApiService.getPlaylistInfo(effective.cleanUrl);
      return PlaylistInfo.fromJson(
        json,
        isChannel: effective.contentType == MediaContentType.channel,
        fallbackUrl: effective.cleanUrl,
      );
    }

    // Channel support on Mobile
    if (effective.contentType == MediaContentType.channel) {
      final channel = await _resolveChannel(effective.cleanUrl);
      final videos = <VideoInfo>[];
      await for (final video
          in _yt.channels.getUploads(channel.id).take(50)) {
        videos.add(
          VideoInfo(
            id: video.id.value,
            title: video.title,
            thumbnail: video.thumbnails.highResUrl,
            duration:
                VideoInfo.formatDurationSeconds(video.duration?.inSeconds ?? 0),
            uploader: channel.title,
            url: video.url,
          ),
        );
      }

      return PlaylistInfo(
        title: channel.title,
        videoCount: videos.length,
        uploader: channel.title,
        entries: videos,
        thumbnail: channel.logoUrl.isNotEmpty
            ? channel.logoUrl
            : (videos.isNotEmpty ? videos.first.thumbnail : ''),
        isChannel: true,
        url: effective.cleanUrl,
      );
    }

    // Standard YouTube Playlist
    final playlist = await _yt.playlists.get(effective.cleanUrl);
    final videos = <VideoInfo>[];
    await for (final video in _yt.playlists.getVideos(playlist.id).take(100)) {
      videos.add(
        VideoInfo(
          id: video.id.value,
          title: video.title,
          thumbnail: video.thumbnails.highResUrl,
          duration:
              VideoInfo.formatDurationSeconds(video.duration?.inSeconds ?? 0),
          uploader: video.author,
          url: video.url,
        ),
      );
    }

    return PlaylistInfo(
      title: playlist.title,
      videoCount: playlist.videoCount ?? videos.length,
      uploader: playlist.author,
      entries: videos,
      thumbnail: videos.isNotEmpty ? videos.first.thumbnail : '',
      isChannel: false,
      url: effective.cleanUrl,
    );
  }

  Future<Channel> _resolveChannel(String cleanUrl) async {
    final uri = Uri.parse(cleanUrl);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      if (segments.first.startsWith('@')) {
        return _yt.channels.getByHandle(segments.first);
      }
      if (segments.first == 'user' && segments.length > 1) {
        return _yt.channels.getByUsername(segments[1]);
      }
      if (segments.first == 'channel' && segments.length > 1) {
        return _yt.channels.get(segments[1]);
      }
    }
    return _yt.channels.get(cleanUrl);
  }

  @override
  Stream<DownloadProgress> downloadPlaylist(
    String url,
    String outputDirectory, {
    List<int>? selectedIndices,
    String? qualityId,
    bool isAudioOnly = false,
    String audioFormat = 'mp3',
    String audioBitrate = '320',
    bool embedMetadata = true,
    bool downloadSubtitles = false,
    ParsedMediaInput? parsed,
  }) async* {
    _cancelRequested = false;
    _isDownloading = true;
    try {
      await _checkPermissions();
      final effective = parsed ?? UrlResolverService.parseInput(url);

      final List<Video> videosToProcess = [];
      if (effective.contentType == MediaContentType.channel) {
        final channel = await _resolveChannel(effective.cleanUrl);
        await for (final v in _yt.channels.getUploads(channel.id).take(100)) {
          videosToProcess.add(v);
        }
      } else {
        final playlist = await _yt.playlists.get(effective.cleanUrl);
        await for (final v in _yt.playlists.getVideos(playlist.id)) {
          videosToProcess.add(v);
        }
      }

      final selected = <({int originalIndex, Video video})>[];
      for (int i = 0; i < videosToProcess.length; i++) {
        final oneBased = i + 1;
        if (selectedIndices == null || selectedIndices.contains(oneBased)) {
          selected.add((originalIndex: oneBased, video: videosToProcess[i]));
        }
      }

      if (selected.isEmpty) {
        throw Exception('No videos selected in playlist.');
      }

      String? lastSavedPath;
      for (int i = 0; i < selected.length; i++) {
        if (_cancelRequested) {
          throw Exception('Download cancelled');
        }

        final entry = selected[i];
        yield DownloadProgress(
          progress: i / selected.length,
          eta: '',
          speed: '',
          status: 'Starting ${i + 1} of ${selected.length}...',
          currentVideoIndex: i + 1,
          totalVideos: selected.length,
          currentVideoTitle: entry.video.title,
        );

        await for (final event in downloadVideo(
          entry.video.url,
          outputDirectory,
          qualityId: qualityId,
          isAudioOnly: isAudioOnly,
          audioFormat: audioFormat,
          audioBitrate: audioBitrate,
          embedMetadata: embedMetadata,
          downloadSubtitles: downloadSubtitles,
        )) {
          if (_cancelRequested) {
            throw Exception('Download cancelled');
          }
          if (event.outputFilePath != null) {
            lastSavedPath = event.outputFilePath;
          }
          yield DownloadProgress(
            progress: event.progress,
            eta: event.eta,
            speed: event.speed,
            status: 'Item ${i + 1}/${selected.length} • ${event.status}',
            currentVideoIndex: i + 1,
            totalVideos: selected.length,
            currentVideoTitle: entry.video.title,
            outputFilePath: event.outputFilePath,
          );
        }
      }

      yield DownloadProgress(
        progress: 1.0,
        eta: '',
        speed: '',
        status: 'Completed (${selected.length} items)',
        currentVideoIndex: selected.length,
        totalVideos: selected.length,
        outputFilePath: lastSavedPath ?? outputDirectory,
      );
    } finally {
      _isDownloading = false;
    }
  }

  @override
  Stream<DownloadProgress> downloadVideo(
    String url,
    String outputDirectory, {
    String? qualityId,
    bool isAudioOnly = false,
    String audioFormat = 'mp3',
    String audioBitrate = '320',
    bool embedMetadata = true,
    bool downloadSubtitles = false,
    ParsedMediaInput? parsed,
  }) async* {
    _cancelRequested = false;
    _isDownloading = true;
    File? activeFile;

    try {
      await _checkPermissions();
      final effective = parsed ?? UrlResolverService.parseInput(url);

      // Route non-YouTube, non-DRM-music URLs via Backend API on Mobile
      if (!effective.platform.isYouTubeFamily &&
          !effective.requiresMusicSearchResolution) {
        yield* _downloadViaBackend(
          effective,
          outputDirectory,
          qualityId: qualityId,
          isAudioOnly: isAudioOnly,
          audioFormat: audioFormat,
        );
        return;
      }

      yield const DownloadProgress(
        progress: 0.0,
        eta: '',
        speed: '',
        status: 'Resolving stream...',
      );

      final resolved = await _resolveYouTubeVideo(url, parsed: effective);
      final video = resolved.video;
      final manifest = await _getManifestResilient(video.id);

      StreamInfo? selectedStream;

      if (isAudioOnly) {
        // Prefer M4A (AAC) audio for universal mobile playback compatibility,
        // falling back to highest bitrate audio-only stream.
        final m4aAudio = manifest.audioOnly
            .where((s) => s.container.name.toLowerCase() == 'mp4' ||
                s.container.name.toLowerCase() == 'm4a')
            .toList();
        if (m4aAudio.isNotEmpty) {
          m4aAudio.sort((a, b) => b.bitrate.compareTo(a.bitrate));
          selectedStream = m4aAudio.first;
        } else if (manifest.audioOnly.isNotEmpty) {
          selectedStream = manifest.audioOnly.withHighestBitrate();
        } else if (manifest.muxed.isNotEmpty) {
          selectedStream = manifest.muxed.withHighestBitrate();
        }
      } else {
        // Mobile has no bundled FFmpeg muxer, so pick the best muxed stream
        // matching or closest to the requested height to ensure audio+video stay synced.
        final targetHeight = (qualityId != null && qualityId != 'Best')
            ? int.tryParse(qualityId.replaceAll(RegExp(r'[^0-9]'), ''))
            : null;

        if (manifest.muxed.isNotEmpty) {
          final sortedMuxed = manifest.muxed.toList()
            ..sort(
              (a, b) =>
                  b.videoResolution.height.compareTo(a.videoResolution.height),
            );
          if (targetHeight != null) {
            selectedStream = sortedMuxed.firstWhere(
              (s) => s.videoResolution.height <= targetHeight,
              orElse: () => sortedMuxed.last,
            );
          } else {
            selectedStream = sortedMuxed.first;
          }
        } else if (manifest.videoOnly.isNotEmpty) {
          selectedStream = manifest.videoOnly.withHighestBitrate();
        }
      }

      if (selectedStream == null) {
        throw Exception('No downloadable stream was found for this video.');
      }

      final displayTitle = resolved.resolvedTrack?.title.isNotEmpty == true
          ? resolved.resolvedTrack!.title
          : video.title;
      final safeTitle = PlatformUtils.sanitizeFilename(displayTitle);

      final dir = Directory(outputDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final ext = isAudioOnly
          ? (selectedStream.container.name == 'mp4'
              ? 'm4a'
              : selectedStream.container.name)
          : selectedStream.container.name;
      final outPath = '$outputDirectory/$safeTitle.$ext';
      activeFile = File(outPath);

      final stream = _yt.videos.streamsClient.get(selectedStream);
      final sink = activeFile.openWrite();
      final totalBytes = selectedStream.size.totalBytes;
      int downloadedBytes = 0;

      final stopwatch = Stopwatch()..start();
      int lastEmitMs = 0;

      try {
        await for (final chunk in stream) {
          if (_cancelRequested) {
            throw Exception('Download cancelled');
          }
          sink.add(chunk);
          downloadedBytes += chunk.length;

          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs - lastEmitMs >= 250 || downloadedBytes >= totalBytes) {
            lastEmitMs = elapsedMs;
            final progress =
                totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
            final elapsedSec = elapsedMs / 1000.0;
            final bytesPerSec =
                elapsedSec > 0 ? (downloadedBytes / elapsedSec) : 0.0;
            final remainingBytes = totalBytes - downloadedBytes;
            final etaSec = bytesPerSec > 0
                ? (remainingBytes / bytesPerSec).round()
                : 0;

            yield DownloadProgress(
              progress: progress,
              speed: _formatSpeed(bytesPerSec),
              eta: etaSec > 0 ? VideoInfo.formatDurationSeconds(etaSec) : '',
              status: 'Downloading',
              currentVideoTitle: displayTitle,
            );
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // Optionally register video in device Gallery so users find it immediately
      if (!isAudioOnly && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await Gal.putVideo(outPath, album: 'Synco');
        } catch (e) {
          debugPrint('Synco: Gallery export skipped: $e');
        }
      }

      yield DownloadProgress(
        progress: 1.0,
        eta: '',
        speed: '',
        status: 'Completed',
        currentVideoTitle: displayTitle,
        outputFilePath: outPath,
      );
    } catch (e) {
      if (_cancelRequested && activeFile != null && await activeFile.exists()) {
        try {
          await activeFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      _isDownloading = false;
    }
  }

  Stream<DownloadProgress> _downloadViaBackend(
    ParsedMediaInput effective,
    String outputDirectory, {
    String? qualityId,
    required bool isAudioOnly,
    required String audioFormat,
  }) async* {
    final quality = (qualityId ?? '1080').replaceAll(RegExp(r'[^0-9]'), '');
    final response = await ApiService.openDownloadStream(
      effective.cleanUrl,
      quality: quality.isEmpty ? '1080' : quality,
      isAudioOnly: isAudioOnly,
      audioFormat: audioFormat,
    );

    final ext = isAudioOnly ? audioFormat : 'mp4';
    final fileName =
        '${PlatformUtils.sanitizeFilename(effective.platform.displayName)}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final outPath = '$outputDirectory/$fileName';
    final file = File(outPath);
    final sink = file.openWrite();

    final contentLength = response.contentLength ?? 0;
    int received = 0;

    try {
      await for (final chunk in response.stream) {
        if (_cancelRequested) {
          throw Exception('Download cancelled');
        }
        sink.add(chunk);
        received += chunk.length;
        yield DownloadProgress(
          progress: contentLength > 0 ? (received / contentLength).clamp(0.0, 1.0) : 0.5,
          speed: '',
          eta: '',
          status: 'Downloading via server...',
        );
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    yield DownloadProgress(
      progress: 1.0,
      speed: '',
      eta: '',
      status: 'Completed',
      outputFilePath: outPath,
    );
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }
}
