import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/services/download_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MobileDownloadService implements DownloadService {
  final YoutubeExplode _yt = YoutubeExplode();
  bool _isDownloading = false;
  // We can't easily cancel youtube_explode streams or ffmpeg via a simple process kill
  // but we can manage cancellation via flags or cancellation tokens in future.
  // For now, basic implementation.
  // TODO: Implement proper cancellation token

  @override
  bool get isDownloading => _isDownloading;

  @override
  void cancelCurrentDownload() {
    // TODO: Implement cancellation for mobile
    _isDownloading = false;
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      // General storage permission (older Android)
      if (await Permission.storage.request().isGranted) {
        // Good for < Android 11
      }

      // Manage full storage access (Android 11+)
      // Note: This requires the MANAGE_EXTERNAL_STORAGE permission in manifest
      if (await Permission.manageExternalStorage.status.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  @override
  Future<VideoInfo> getVideoInfo(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      // Extract available qualities
      final Set<String> qualities = {};

      // VideoOnly streams usually have higher quality (1080p+)
      for (var s in manifest.videoOnly) {
        qualities.add('${s.videoResolution.height}p');
      }
      // Muxed streams (720p and below)
      for (var s in manifest.muxed) {
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
        title: video.title,
        thumbnail: video.thumbnails.highResUrl,
        duration: video.duration?.toString() ?? '0:00',
        uploader: video.author,
        availableQualities: sortedQualities,
      );
    } catch (e) {
      throw Exception('Failed to fetch video info: $e');
    }
  }

  @override
  Future<PlaylistInfo> getPlaylistInfo(String url) async {
    try {
      final playlist = await _yt.playlists.get(url);

      // Fetch videos (limit to first 50 or fetch all? Seal fetches all usually)
      // fetch first batch for UI speed
      final videos = <VideoInfo>[];
      await for (final video in _yt.playlists.getVideos(playlist.id).take(50)) {
        videos.add(
          VideoInfo(
            id: video.id.value,
            title: video.title,
            thumbnail: video.thumbnails.highResUrl,
            duration: video.duration?.toString() ?? '0:00',
            uploader: video.author,
          ),
        );
      }

      return PlaylistInfo(
        title: playlist.title,
        videoCount: playlist.videoCount ?? videos.length,
        uploader: playlist.author,
        entries: videos,
        thumbnail: videos.isNotEmpty ? videos.first.thumbnail : '',
      );
    } catch (e) {
      throw Exception('Failed to fetch playlist info: $e');
    }
  }

  @override
  Stream<DownloadProgress> downloadPlaylist(
    String url,
    String outputDirectory, {
    List<int>? selectedIndices,
    String? qualityId,
    bool isAudioOnly = false,
  }) async* {
    try {
      await _checkPermissions();
      final playlist = await _yt.playlists.get(url);
      var index = 0;

      // Need to fetch videos again to iterate properly
      await for (final video in _yt.playlists.getVideos(playlist.id)) {
        index++;

        // Check selection
        if (selectedIndices != null && !selectedIndices.contains(index)) {
          continue;
        }

        yield DownloadProgress(
          progress: 0.0,
          eta: '',
          speed: '',
          status: 'Starting video $index...',
          currentVideoIndex: index,
          totalVideos: playlist.videoCount ?? 0,
          currentVideoTitle: video.title,
        );

        final videoUrl = video.url;
        await for (final event in downloadVideo(
          videoUrl,
          outputDirectory,
          qualityId: qualityId,
          isAudioOnly: isAudioOnly,
        )) {
          // Forward progress but update contextual info
          yield DownloadProgress(
            progress: event.progress,
            eta: event.eta,
            speed: event.speed,
            status: event.status,
            currentVideoIndex: index,
            totalVideos: playlist.videoCount ?? 0,
            currentVideoTitle: video.title, // Keep title of current video
          );
        }
      }
    } catch (e) {
      debugPrint('Mobile Download Error: $e');
      yield DownloadProgress(
        progress: 0,
        eta: '',
        speed: '',
        status: 'Error: $e',
      );
    }
  }

  @override
  Stream<DownloadProgress> downloadVideo(
    String url,
    String outputDirectory, {
    String? qualityId,
    bool isAudioOnly = false,
  }) async* {
    _isDownloading = true;
    try {
      await _checkPermissions();
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      StreamInfo? streamInfo;
      StreamInfo? audioStreamInfo;

      if (isAudioOnly) {
        audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        streamInfo = audioStreamInfo;
      } else {
        // Video logic
        if (qualityId != null && qualityId != 'Best') {
          final targetHeight =
              int.tryParse(qualityId.replaceAll('p', '')) ?? 1080;

          // Try to find muxed first (easier)
          try {
            streamInfo = manifest.muxed.firstWhere(
              (s) => s.videoResolution.height == targetHeight,
            );
          } catch (_) {
            if (manifest.muxed.isNotEmpty) {
              streamInfo = manifest.muxed.withHighestBitrate();
            }
          }

          // If muxed resolution is too low compared to target, try videoOnly + audioOnly
          bool useVideoOnly = false;
          if (streamInfo is MuxedStreamInfo) {
            if (streamInfo.videoResolution.height < targetHeight) {
              useVideoOnly = true;
            }
          } else if (streamInfo == null) {
            useVideoOnly = true;
          }

          if (useVideoOnly) {
            VideoStreamInfo? bestVideo;
            try {
              bestVideo = manifest.videoOnly.firstWhere(
                (s) => s.videoResolution.height == targetHeight,
              );
            } catch (_) {
              if (manifest.videoOnly.isNotEmpty) {
                bestVideo = manifest.videoOnly.withHighestBitrate();
              }
            }

            // If the video-only stream is better, use it and merge
            // We compare heights if possible
            if (bestVideo != null) {
              bool isBetter = false;
              if (streamInfo is MuxedStreamInfo) {
                if (bestVideo.videoResolution.height >
                    streamInfo.videoResolution.height) {
                  isBetter = true;
                }
              } else if (streamInfo == null) {
                isBetter = true;
              }

              if (isBetter) {
                streamInfo = bestVideo;
                audioStreamInfo = manifest.audioOnly.withHighestBitrate();
              }
            }
          }
        } else {
          // Best quality
          streamInfo = manifest.videoOnly.isNotEmpty
              ? manifest.videoOnly.withHighestBitrate()
              : (manifest.muxed.isNotEmpty
                    ? manifest.muxed.withHighestBitrate()
                    : null);

          audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        }
      }

      if (streamInfo == null) {
        throw Exception('No suitable stream found');
      }

      // 1. Download Content
      // SIMPLIFIED FOR ANDROID STABILITY: Muxed streams only (Max 720p)
      // FFmpeg caused build issues, so we temporarily removed it.

      // Force muxed stream if we ended up with a separate audio stream (shouldn't happen with updated logic below, but safety check)
      if (streamInfo is! MuxedStreamInfo && audioStreamInfo != null) {
        // Fallback to best muxed
        streamInfo = manifest.muxed.withHighestBitrate();
      }

      final safeTitle = video.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final dir = Directory(outputDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final ext = streamInfo.container.name;
      final outPath = '$outputDirectory/$safeTitle.$ext';
      final file = File(outPath);

      final videoStream = _yt.videos.streamsClient.get(streamInfo);
      final videoOutput = file.openWrite();
      var len = streamInfo.size.totalBytes;
      var count = 0;

      await for (final chunk in videoStream) {
        count += chunk.length;
        videoOutput.add(chunk);

        final progress = count / len;
        yield DownloadProgress(
          progress: progress,
          eta: '',
          speed: '',
          status: 'Downloading...',
          currentVideoTitle: video.title,
        );
      }
      await videoOutput.flush();
      await videoOutput.close();

      yield DownloadProgress(
        progress: 1.0,
        eta: '',
        speed: '',
        status: 'Complete',
        currentVideoTitle: video.title,
      );
    } catch (e) {
      debugPrint('Error: $e');
      yield DownloadProgress(
        progress: 0,
        eta: '',
        speed: '',
        status: 'Error: $e',
      );
      rethrow;
    } finally {
      _isDownloading = false;
    }
  }
}
