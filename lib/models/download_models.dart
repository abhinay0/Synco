enum AppMediaMode { video, music }

enum MediaSourcePlatform {
  youtube,
  youtubeMusic,
  spotify,
  appleMusic,
  amazonMusic,
  soundcloud,
  instagram,
  tiktok,
  twitter,
  reddit,
  vimeo,
  twitch,
  facebook,
  generic,
}

enum MediaContentType { video, audio, playlist, channel, search }

enum DownloadTaskStatus {
  queued,
  resolving,
  downloading,
  completed,
  failed,
  cancelled,
}

extension MediaSourcePlatformX on MediaSourcePlatform {
  String get displayName {
    switch (this) {
      case MediaSourcePlatform.youtube:
        return 'YouTube';
      case MediaSourcePlatform.youtubeMusic:
        return 'YouTube Music';
      case MediaSourcePlatform.spotify:
        return 'Spotify';
      case MediaSourcePlatform.appleMusic:
        return 'Apple Music';
      case MediaSourcePlatform.amazonMusic:
        return 'Amazon Music';
      case MediaSourcePlatform.soundcloud:
        return 'SoundCloud';
      case MediaSourcePlatform.instagram:
        return 'Instagram';
      case MediaSourcePlatform.tiktok:
        return 'TikTok';
      case MediaSourcePlatform.twitter:
        return 'X / Twitter';
      case MediaSourcePlatform.reddit:
        return 'Reddit';
      case MediaSourcePlatform.vimeo:
        return 'Vimeo';
      case MediaSourcePlatform.twitch:
        return 'Twitch';
      case MediaSourcePlatform.facebook:
        return 'Facebook';
      case MediaSourcePlatform.generic:
        return 'Media Stream';
    }
  }

  bool get isYouTubeFamily =>
      this == MediaSourcePlatform.youtube ||
      this == MediaSourcePlatform.youtubeMusic;

  bool get isDrmMusicService =>
      this == MediaSourcePlatform.spotify ||
      this == MediaSourcePlatform.appleMusic ||
      this == MediaSourcePlatform.amazonMusic;
}

class ParsedMediaInput {
  final String rawInput;
  final String cleanUrl;
  final MediaSourcePlatform platform;
  final MediaContentType contentType;
  final String? searchHint;
  final String displayDomain;
  final bool isValid;

  const ParsedMediaInput({
    required this.rawInput,
    required this.cleanUrl,
    required this.platform,
    required this.contentType,
    required this.displayDomain,
    required this.isValid,
    this.searchHint,
  });

  bool get requiresMusicSearchResolution =>
      platform.isDrmMusicService || contentType == MediaContentType.search;

  bool get isCollection =>
      contentType == MediaContentType.playlist ||
      contentType == MediaContentType.channel;
}

class ResolvedMusicTrack {
  final String title;
  final String artist;
  final String thumbnail;
  final String searchQuery;
  final String sourceLabel;

  const ResolvedMusicTrack({
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.searchQuery,
    required this.sourceLabel,
  });
}

class FriendlyErrorInfo {
  final String summary;
  final String details;
  final String fixHint;
  final bool isEngineFixable;

  const FriendlyErrorInfo({
    required this.summary,
    required this.details,
    required this.fixHint,
    this.isEngineFixable = false,
  });
}

class VideoInfo {
  final String id;
  final String title;
  final String thumbnail;
  final String duration;
  final String uploader;
  final String url;
  final MediaSourcePlatform platform;
  final List<String> availableQualities;

  const VideoInfo({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.uploader,
    this.url = '',
    this.platform = MediaSourcePlatform.youtube,
    this.availableQualities = const [],
  });

  factory VideoInfo.fromJson(
    Map<String, dynamic> json, {
    MediaSourcePlatform platform = MediaSourcePlatform.generic,
  }) {
    final Set<String> qualities = {};
    final formats = json['formats'];
    if (formats is List) {
      for (final f in formats) {
        if (f is Map && f['height'] != null) {
          final height = int.tryParse(f['height'].toString());
          if (height != null && height >= 144) {
            qualities.add('${height}p');
          }
        }
      }
    }

    final sortedQualities = qualities.toList()
      ..sort((a, b) {
        final hA = int.tryParse(a.replaceAll('p', '')) ?? 0;
        final hB = int.tryParse(b.replaceAll('p', '')) ?? 0;
        return hB.compareTo(hA);
      });

    String durationText = json['duration_string']?.toString() ?? '';
    if (durationText.isEmpty && json['duration'] != null) {
      final secs = double.tryParse(json['duration'].toString())?.round() ?? 0;
      durationText = formatDurationSeconds(secs);
    }

    return VideoInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      thumbnail: json['thumbnail']?.toString() ?? '',
      duration: durationText.isEmpty ? '0:00' : durationText,
      uploader:
          json['uploader']?.toString() ??
          json['channel']?.toString() ??
          json['artist']?.toString() ??
          'Unknown Creator',
      url: json['webpage_url']?.toString() ?? json['original_url']?.toString() ?? '',
      platform: platform,
      availableQualities: sortedQualities,
    );
  }

  static String formatDurationSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final secStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final minStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minStr:$secStr';
    }
    return '$minutes:$secStr';
  }
}

class PlaylistInfo {
  final String title;
  final int videoCount;
  final String uploader;
  final String thumbnail;
  final List<VideoInfo> entries;
  final bool isChannel;
  final String url;

  const PlaylistInfo({
    required this.title,
    required this.videoCount,
    required this.uploader,
    required this.entries,
    this.thumbnail = '',
    this.isChannel = false,
    this.url = '',
  });

  factory PlaylistInfo.fromJson(
    Map<String, dynamic> json, {
    bool isChannel = false,
    String fallbackUrl = '',
  }) {
    final List<VideoInfo> parsedEntries = [];
    final rawEntries = json['entries'];
    if (rawEntries is List) {
      for (final rawEntry in rawEntries) {
        if (rawEntry is! Map) continue;
        final videoId = rawEntry['id']?.toString() ?? '';
        String thumbUrl = rawEntry['thumbnail']?.toString() ?? '';
        if (thumbUrl.isEmpty && rawEntry['thumbnails'] is List) {
          final thumbs = rawEntry['thumbnails'] as List;
          if (thumbs.isNotEmpty && thumbs.last is Map) {
            thumbUrl = (thumbs.last as Map)['url']?.toString() ?? '';
          }
        }
        if (thumbUrl.isEmpty && videoId.length == 11) {
          thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
        }

        final entryUrl = rawEntry['url']?.toString() ??
            rawEntry['webpage_url']?.toString() ??
            (videoId.length == 11
                ? 'https://www.youtube.com/watch?v=$videoId'
                : '');

        String durationText = rawEntry['duration_string']?.toString() ?? '';
        if (durationText.isEmpty && rawEntry['duration'] != null) {
          final secs =
              double.tryParse(rawEntry['duration'].toString())?.round() ?? 0;
          durationText = VideoInfo.formatDurationSeconds(secs);
        }

        parsedEntries.add(
          VideoInfo(
            id: videoId,
            title: rawEntry['title']?.toString() ?? 'Untitled Video',
            thumbnail: thumbUrl,
            duration: durationText,
            uploader:
                rawEntry['uploader']?.toString() ??
                rawEntry['channel']?.toString() ??
                json['uploader']?.toString() ??
                '',
            url: entryUrl,
          ),
        );
      }
    }

    String playlistThumb = json['thumbnail']?.toString() ?? '';
    if (playlistThumb.isEmpty && json['thumbnails'] is List) {
      final thumbs = json['thumbnails'] as List;
      if (thumbs.isNotEmpty && thumbs.last is Map) {
        playlistThumb = (thumbs.last as Map)['url']?.toString() ?? '';
      }
    }
    if (playlistThumb.isEmpty && parsedEntries.isNotEmpty) {
      playlistThumb = parsedEntries.first.thumbnail;
    }

    return PlaylistInfo(
      title: json['title']?.toString() ??
          (isChannel ? 'Channel Uploads' : 'Untitled Playlist'),
      videoCount:
          int.tryParse(json['playlist_count']?.toString() ?? '') ??
          parsedEntries.length,
      uploader:
          json['uploader']?.toString() ??
          json['channel']?.toString() ??
          'Unknown Creator',
      entries: parsedEntries,
      thumbnail: playlistThumb,
      isChannel: isChannel,
      url: json['webpage_url']?.toString() ?? fallbackUrl,
    );
  }
}

class DownloadConfiguration {
  final List<int>? selectedIndices;
  final String qualityId;
  final bool isAudioOnly;
  final String audioFormat;
  final String audioBitrate;
  final bool embedMetadata;
  final bool downloadSubtitles;

  const DownloadConfiguration({
    this.selectedIndices,
    required this.qualityId,
    required this.isAudioOnly,
    this.audioFormat = 'mp3',
    this.audioBitrate = '320',
    this.embedMetadata = true,
    this.downloadSubtitles = false,
  });

  String get badgeLabel {
    if (isAudioOnly) {
      return audioFormat.toUpperCase();
    }
    if (qualityId == 'Best') return 'BEST';
    return qualityId.toUpperCase();
  }
}

class DownloadProgress {
  final double progress;
  final String eta;
  final String speed;
  final String status;
  final String currentVideoTitle;
  final int currentVideoIndex;
  final int totalVideos;
  final String? outputFilePath;

  const DownloadProgress({
    required this.progress,
    required this.eta,
    required this.speed,
    required this.status,
    this.currentVideoTitle = '',
    this.currentVideoIndex = 0,
    this.totalVideos = 0,
    this.outputFilePath,
  });
}

class DownloadTask {
  final String id;
  final String rawInput;
  final String resolvedUrl;
  final String title;
  final String subtitle;
  final String thumbnail;
  final MediaSourcePlatform platform;
  final MediaContentType contentType;
  final AppMediaMode mode;
  final String qualityLabel;
  final String qualityId;
  final String audioFormat;
  final String audioBitrate;
  final bool isAudioOnly;
  final bool embedMetadata;
  final bool downloadSubtitles;
  final List<int>? selectedIndices;
  final DownloadTaskStatus status;
  final double progress;
  final String speed;
  final String eta;
  final String statusMessage;
  final int currentItemIndex;
  final int totalItems;
  final String currentItemTitle;
  final String outputPath;
  final String? errorSummary;
  final String? errorDetails;
  final String? errorFixHint;
  final bool isEngineFixable;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.rawInput,
    required this.resolvedUrl,
    required this.title,
    required this.subtitle,
    required this.thumbnail,
    required this.platform,
    required this.contentType,
    required this.mode,
    required this.qualityLabel,
    required this.qualityId,
    required this.audioFormat,
    required this.audioBitrate,
    required this.isAudioOnly,
    required this.embedMetadata,
    required this.downloadSubtitles,
    this.selectedIndices,
    required this.status,
    this.progress = 0.0,
    this.speed = '',
    this.eta = '',
    this.statusMessage = 'Queued',
    this.currentItemIndex = 0,
    this.totalItems = 1,
    this.currentItemTitle = '',
    this.outputPath = '',
    this.errorSummary,
    this.errorDetails,
    this.errorFixHint,
    this.isEngineFixable = false,
    required this.createdAt,
    this.completedAt,
  });

  bool get isActive =>
      status == DownloadTaskStatus.queued ||
      status == DownloadTaskStatus.resolving ||
      status == DownloadTaskStatus.downloading;

  DownloadTask copyWith({
    String? resolvedUrl,
    String? title,
    String? subtitle,
    String? thumbnail,
    MediaSourcePlatform? platform,
    MediaContentType? contentType,
    String? qualityLabel,
    DownloadTaskStatus? status,
    double? progress,
    String? speed,
    String? eta,
    String? statusMessage,
    int? currentItemIndex,
    int? totalItems,
    String? currentItemTitle,
    String? outputPath,
    String? errorSummary,
    String? errorDetails,
    String? errorFixHint,
    bool? isEngineFixable,
    bool clearError = false,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id,
      rawInput: rawInput,
      resolvedUrl: resolvedUrl ?? this.resolvedUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      thumbnail: thumbnail ?? this.thumbnail,
      platform: platform ?? this.platform,
      contentType: contentType ?? this.contentType,
      mode: mode,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      qualityId: qualityId,
      audioFormat: audioFormat,
      audioBitrate: audioBitrate,
      isAudioOnly: isAudioOnly,
      embedMetadata: embedMetadata,
      downloadSubtitles: downloadSubtitles,
      selectedIndices: selectedIndices,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      statusMessage: statusMessage ?? this.statusMessage,
      currentItemIndex: currentItemIndex ?? this.currentItemIndex,
      totalItems: totalItems ?? this.totalItems,
      currentItemTitle: currentItemTitle ?? this.currentItemTitle,
      outputPath: outputPath ?? this.outputPath,
      errorSummary: clearError ? null : (errorSummary ?? this.errorSummary),
      errorDetails: clearError ? null : (errorDetails ?? this.errorDetails),
      errorFixHint: clearError ? null : (errorFixHint ?? this.errorFixHint),
      isEngineFixable: clearError ? false : (isEngineFixable ?? this.isEngineFixable),
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawInput': rawInput,
      'resolvedUrl': resolvedUrl,
      'title': title,
      'subtitle': subtitle,
      'thumbnail': thumbnail,
      'platform': platform.name,
      'contentType': contentType.name,
      'mode': mode.name,
      'qualityLabel': qualityLabel,
      'qualityId': qualityId,
      'audioFormat': audioFormat,
      'audioBitrate': audioBitrate,
      'isAudioOnly': isAudioOnly,
      'embedMetadata': embedMetadata,
      'downloadSubtitles': downloadSubtitles,
      'selectedIndices': selectedIndices,
      'status': status.name,
      'progress': progress,
      'outputPath': outputPath,
      'errorSummary': errorSummary,
      'errorDetails': errorDetails,
      'errorFixHint': errorFixHint,
      'isEngineFixable': isEngineFixable,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      rawInput: json['rawInput']?.toString() ?? '',
      resolvedUrl: json['resolvedUrl']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Media',
      subtitle: json['subtitle']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      platform: MediaSourcePlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => MediaSourcePlatform.generic,
      ),
      contentType: MediaContentType.values.firstWhere(
        (e) => e.name == json['contentType'],
        orElse: () => MediaContentType.video,
      ),
      mode: AppMediaMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => AppMediaMode.video,
      ),
      qualityLabel: json['qualityLabel']?.toString() ?? 'BEST',
      qualityId: json['qualityId']?.toString() ?? 'Best',
      audioFormat: json['audioFormat']?.toString() ?? 'mp3',
      audioBitrate: json['audioBitrate']?.toString() ?? '320',
      isAudioOnly: json['isAudioOnly'] == true,
      embedMetadata: json['embedMetadata'] != false,
      downloadSubtitles: json['downloadSubtitles'] == true,
      selectedIndices: (json['selectedIndices'] as List?)
          ?.map((e) => int.tryParse(e.toString()) ?? 1)
          .toList(),
      status: DownloadTaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadTaskStatus.completed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
      outputPath: json['outputPath']?.toString() ?? '',
      errorSummary: json['errorSummary']?.toString(),
      errorDetails: json['errorDetails']?.toString(),
      errorFixHint: json['errorFixHint']?.toString(),
      isEngineFixable: json['isEngineFixable'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }
}

class EngineDiagnostics {
  final bool ytDlpAvailable;
  final String ytDlpVersion;
  final bool ffmpegAvailable;
  final String jsRuntimeName;
  final String jsRuntimePath;
  final bool backendReachable;
  final String platformLabel;

  const EngineDiagnostics({
    required this.ytDlpAvailable,
    required this.ytDlpVersion,
    required this.ffmpegAvailable,
    required this.jsRuntimeName,
    required this.jsRuntimePath,
    required this.backendReachable,
    required this.platformLabel,
  });

  bool get hasJsRuntime => jsRuntimeName.isNotEmpty;
}
