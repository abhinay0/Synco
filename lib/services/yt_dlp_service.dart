import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper to get environment with full PATH for macOS
Map<String, String> _getEnvWithPath() {
  final env = Map<String, String>.from(Platform.environment);
  // Add common paths for yt-dlp and ffmpeg on macOS
  final additionalPaths = [
    '/opt/homebrew/bin', // Apple Silicon Homebrew
    '/usr/local/bin', // Intel Homebrew
    '/usr/bin',
    '/bin',
    '/usr/sbin',
    '/sbin',
    Platform.environment['HOME'] != null
        ? '${Platform.environment['HOME']}/.local/bin'
        : '',
  ].where((p) => p.isNotEmpty).join(':');

  final currentPath = env['PATH'] ?? '';
  env['PATH'] = '$additionalPaths:$currentPath';
  return env;
}

class VideoInfo {
  final String id;
  final String title;
  final String thumbnail;
  final String duration;
  final String uploader;
  final List<String> availableQualities; // e.g. ['2160p', '1080p', '720p']

  VideoInfo({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.uploader,
    this.availableQualities = const [],
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    // Parse formats to find unique resolutions
    final Set<String> qualities = {};
    if (json['formats'] != null) {
      for (var f in json['formats']) {
        if (f['height'] != null) {
          qualities.add('${f['height']}p');
        }
      }
    }
    // Sort qualities descending (rough logic)
    final sortedQualities = qualities.toList()
      ..sort((a, b) {
        final hA = int.tryParse(a.replaceAll('p', '')) ?? 0;
        final hB = int.tryParse(b.replaceAll('p', '')) ?? 0;
        return hB.compareTo(hA);
      });

    return VideoInfo(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      thumbnail: json['thumbnail'] ?? '',
      duration: json['duration_string'] ?? '0:00',
      uploader: json['uploader'] ?? 'Unknown Uploader',
      availableQualities: sortedQualities,
    );
  }
}

class DownloadProgress {
  final double progress; // 0.0 to 1.0
  final String eta;
  final String speed;
  final String status;
  final String currentVideoTitle; // Current video being downloaded
  final int currentVideoIndex; // 1-based index in playlist
  final int totalVideos; // Total videos in playlist

  DownloadProgress({
    required this.progress,
    required this.eta,
    required this.speed,
    required this.status,
    this.currentVideoTitle = '',
    this.currentVideoIndex = 0,
    this.totalVideos = 0,
  });
}

class PlaylistInfo {
  final String title;
  final int videoCount;
  final String uploader;
  final String thumbnail; // Playlist thumbnail URL
  final List<VideoInfo> entries;

  PlaylistInfo({
    required this.title,
    required this.videoCount,
    required this.uploader,
    required this.entries,
    this.thumbnail = '',
  });

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    List<VideoInfo> parsedEntries = [];
    if (json['entries'] != null) {
      for (var entry in json['entries']) {
        // Get video ID for thumbnail construction
        final videoId = entry['id'] ?? '';
        // Construct YouTube thumbnail URL from video ID if not provided
        String thumbUrl = entry['thumbnail'] ?? '';
        if (thumbUrl.isEmpty && videoId.isNotEmpty) {
          thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
        }

        parsedEntries.add(
          VideoInfo(
            id: videoId,
            title: entry['title'] ?? 'Unknown Title',
            thumbnail: thumbUrl,
            duration: entry['duration_string'] ?? '',
            uploader: entry['uploader'] ?? '',
          ),
        );
      }
    }

    // Get playlist thumbnail - try multiple sources
    String playlistThumb = json['thumbnail'] ?? '';
    if (playlistThumb.isEmpty &&
        json['entries'] != null &&
        (json['entries'] as List).isNotEmpty) {
      // Try first entry's thumbnail from JSON
      playlistThumb = json['entries'][0]['thumbnail'] ?? '';
      // If still empty, construct from first video ID
      if (playlistThumb.isEmpty) {
        final firstVideoId = json['entries'][0]['id'] ?? '';
        if (firstVideoId.isNotEmpty) {
          playlistThumb = 'https://i.ytimg.com/vi/$firstVideoId/hqdefault.jpg';
        }
      }
    }

    return PlaylistInfo(
      title: json['title'] ?? 'Unknown Playlist',
      videoCount: json['playlist_count'] ?? parsedEntries.length,
      uploader: json['uploader'] ?? 'Unknown Uploader',
      entries: parsedEntries,
      thumbnail: playlistThumb,
    );
  }
}

class YtDlpService {
  // Track current download process for cancellation
  Process? _currentProcess;

  // Preferences key for last update check
  static const String _lastUpdateCheckKey = 'ytdlp_last_update_check';
  static const int _updateIntervalDays = 30; // Monthly updates

  /// Returns true if a download is currently in progress
  bool get isDownloading => _currentProcess != null;

  /// Cancel the current download
  void cancelCurrentDownload() {
    if (_currentProcess != null) {
      debugPrint('Synco: Cancelling download...');
      _currentProcess!.kill(ProcessSignal.sigterm);
      _currentProcess = null;
    }
  }

  /// Check and update yt-dlp if needed (monthly for desktop)
  Future<void> checkAndUpdateYtDlp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString(_lastUpdateCheckKey);

      bool shouldUpdate = true;
      if (lastCheckStr != null) {
        final lastCheck = DateTime.parse(lastCheckStr);
        final daysSinceUpdate = DateTime.now().difference(lastCheck).inDays;
        shouldUpdate = daysSinceUpdate >= _updateIntervalDays;
      }

      if (shouldUpdate) {
        debugPrint('Synco: Checking for yt-dlp updates...');
        final result = await Process.run('yt-dlp', [
          '--update',
        ], environment: _getEnvWithPath());
        if (result.exitCode == 0) {
          debugPrint('Synco: yt-dlp update check completed');
          await prefs.setString(
            _lastUpdateCheckKey,
            DateTime.now().toIso8601String(),
          );
        } else {
          debugPrint('Synco: yt-dlp update check failed: ${result.stderr}');
        }
      } else {
        debugPrint('Synco: yt-dlp update not needed');
      }
    } catch (e) {
      debugPrint('Synco: Error checking yt-dlp updates: $e');
    }
  }

  // Method to fetch video metadata
  Future<VideoInfo> getVideoInfo(String url) async {
    try {
      debugPrint('Synco: Fetching video info locally');
      final result = await Process.run('yt-dlp', [
        '--dump-json',
        '--no-playlist',
        url,
      ], environment: _getEnvWithPath());

      if (result.exitCode != 0) {
        throw Exception('Failed to fetch video info: ${result.stderr}');
      }

      final Map<String, dynamic> json = jsonDecode(result.stdout.toString());
      return VideoInfo.fromJson(json);
    } catch (e) {
      throw Exception('Error fetching video info: $e');
    }
  }

  // Method to fetch playlist metadata
  Future<PlaylistInfo> getPlaylistInfo(String url) async {
    try {
      debugPrint('Synco: Fetching playlist info locally');
      // Use --flat-playlist to get list quickly without downloading everything
      final result = await Process.run('yt-dlp', [
        '--dump-single-json',
        '--flat-playlist',
        url,
      ], environment: _getEnvWithPath());

      if (result.exitCode != 0) {
        throw Exception('Failed to fetch playlist info: ${result.stderr}');
      }

      final Map<String, dynamic> json = jsonDecode(result.stdout.toString());
      return PlaylistInfo.fromJson(json);
    } catch (e) {
      throw Exception('Error fetching playlist info: $e');
    }
  }

  Stream<DownloadProgress> downloadPlaylist(
    String url,
    String outputDirectory, {
    List<int>? selectedIndices,
    String? qualityId,
    bool isAudioOnly = false,
  }) async* {
    // Build args in correct order: [format flags] [playlist-items] [output] [options] [url]
    final List<String> args = [];

    // 1. Format selection first
    if (isAudioOnly) {
      args.addAll(['-x', '--audio-format', 'mp3']);
    } else {
      args.addAll(['--merge-output-format', 'mp4']);
      if (qualityId != null && qualityId != 'Best') {
        final height = qualityId.replaceAll('p', '');
        // Use simpler format string with fallbacks for better compatibility
        args.addAll([
          '-f',
          'bv*[height<=$height]+ba/b[height<=$height]/bv*+ba/b',
        ]);
      } else {
        // Best quality with multiple fallbacks
        args.addAll(['-f', 'bv*+ba/b']);
      }
    }

    // 2. Playlist items selection
    if (selectedIndices != null && selectedIndices.isNotEmpty) {
      args.addAll(['--playlist-items', selectedIndices.join(',')]);
    }

    // 3. Output and options
    args.addAll([
      '-o',
      '$outputDirectory/%(title)s.%(ext)s',
      '--newline',
      '--yes-playlist',
    ]);

    // 4. URL last
    args.add(url);

    debugPrint('Synco: yt-dlp args = $args');
    final process = await Process.start(
      'yt-dlp',
      args,
      environment: _getEnvWithPath(),
    );
    _currentProcess = process;

    yield* _parseProgress(process);
    _currentProcess = null;
  }

  // Method to download video and stream progress
  Stream<DownloadProgress> downloadVideo(
    String url,
    String outputDirectory, {
    String? qualityId,
    bool isAudioOnly = false,
  }) async* {
    final List<String> args = [
      '-o',
      '$outputDirectory/%(title)s.%(ext)s',
      '--newline',
      '--no-playlist',
      url,
    ];

    if (isAudioOnly) {
      args.insertAll(0, ['-x', '--audio-format', 'mp3']);
    } else {
      // Always ensure MP4 output and merge audio+video
      args.insertAll(0, ['--merge-output-format', 'mp4']);
      if (qualityId != null && qualityId != 'Best') {
        final height = qualityId.replaceAll('p', '');
        // Use simpler format string with fallbacks for better compatibility
        args.insertAll(0, [
          '-f',
          'bv*[height<=$height]+ba/b[height<=$height]/bv*+ba/b',
        ]);
      } else {
        // Best quality with multiple fallbacks
        args.insertAll(0, ['-f', 'bv*+ba/b']);
      }
    }

    final process = await Process.start(
      'yt-dlp',
      args,
      environment: _getEnvWithPath(),
    );
    _currentProcess = process;

    yield* _parseProgress(process);
    _currentProcess = null;
  }

  Stream<DownloadProgress> _parseProgress(Process process) async* {
    // Regex to match yt-dlp progress output
    // Example: [download]  45.0% of 10.00MiB at 2.50MiB/s ETA 00:03
    final progressRegex = RegExp(
      r'\[download\]\s+(\d+\.?\d*)%\s+of\s+.*\s+at\s+(.*)\s+ETA\s+(.*)',
    );
    // Regex for playlist video counter: [download] Downloading item 1 of 5
    final playlistCounterRegex = RegExp(
      r'\[download\]\s+Downloading\s+item\s+(\d+)\s+of\s+(\d+)',
    );
    // Regex for destination: [download] Destination: /path/to/VideoTitle.f123.mp4
    final destinationRegex = RegExp(
      r'\[download\]\s+Destination:\s+.*/(.+?)\.(?:f\d+\.)?(?:mp4|webm|mkv|mp3|m4a)',
    );

    // State tracking for playlist downloads
    int currentVideoIndex = 0;
    int totalVideos = 0;
    String currentVideoTitle = '';

    // Collect stderr in background for error reporting
    final stderrBuffer = StringBuffer();
    process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
      debugPrint('Synco stderr: $data');
    });

    await for (final event
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final line = event.trim();
      debugPrint('Synco stdout: $line');

      // Check for playlist counter (Downloading item X of Y)
      final playlistMatch = playlistCounterRegex.firstMatch(line);
      if (playlistMatch != null) {
        currentVideoIndex = int.tryParse(playlistMatch.group(1) ?? '') ?? 0;
        totalVideos = int.tryParse(playlistMatch.group(2) ?? '') ?? 0;
        currentVideoTitle = ''; // Reset title for new video
        yield DownloadProgress(
          progress: 0.0,
          eta: '',
          speed: '',
          status: 'Video $currentVideoIndex of $totalVideos',
          currentVideoIndex: currentVideoIndex,
          totalVideos: totalVideos,
          currentVideoTitle: currentVideoTitle,
        );
        continue;
      }

      // Check for destination to extract video title
      final destMatch = destinationRegex.firstMatch(line);
      if (destMatch != null) {
        currentVideoTitle = destMatch.group(1) ?? '';
        yield DownloadProgress(
          progress: 0.0,
          eta: '',
          speed: '',
          status: 'Starting...',
          currentVideoIndex: currentVideoIndex,
          totalVideos: totalVideos,
          currentVideoTitle: currentVideoTitle,
        );
        continue;
      }

      // Parse progress
      final match = progressRegex.firstMatch(line);
      if (match != null) {
        final percentStr = match.group(1);
        final speed = match.group(2) ?? '';
        final eta = match.group(3) ?? '';

        if (percentStr != null) {
          final progress = double.tryParse(percentStr) ?? 0.0;
          yield DownloadProgress(
            progress: progress / 100,
            speed: speed,
            eta: eta,
            status: 'Downloading',
            currentVideoIndex: currentVideoIndex,
            totalVideos: totalVideos,
            currentVideoTitle: currentVideoTitle,
          );
        }
      } else if (line.contains('has already been downloaded')) {
        yield DownloadProgress(
          progress: 1.0,
          eta: 'Done',
          speed: '',
          status: 'Already downloaded',
          currentVideoIndex: currentVideoIndex,
          totalVideos: totalVideos,
          currentVideoTitle: currentVideoTitle,
        );
      } else if (line.contains('ERROR:') || line.contains('error:')) {
        // Log errors visible in output
        debugPrint('Synco download error: $line');
      }
    }

    final exitCode = await process.exitCode;
    debugPrint('Synco: yt-dlp exit code = $exitCode');

    if (exitCode != 0) {
      final stderr = stderrBuffer.toString();
      debugPrint('Synco: yt-dlp stderr = $stderr');
      // Don't throw for non-zero exit if we got some downloads
      // yt-dlp returns non-zero even if just one video in playlist fails
    }

    yield DownloadProgress(
      progress: 1.0,
      eta: '',
      speed: '',
      status: 'Completed',
      currentVideoIndex: currentVideoIndex,
      totalVideos: totalVideos,
      currentVideoTitle: '',
    );
  }
}
