class VideoInfo {
  final String id;
  final String title;
  final String thumbnail;
  final String duration;
  final String uploader;
  final List<String> availableQualities;

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
    // Sort qualities descending
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

class PlaylistInfo {
  final String title;
  final int videoCount;
  final String uploader;
  final String thumbnail;
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
        final videoId = entry['id'] ?? '';
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

    String playlistThumb = json['thumbnail'] ?? '';
    if (playlistThumb.isEmpty &&
        json['entries'] != null &&
        (json['entries'] as List).isNotEmpty) {
      playlistThumb = json['entries'][0]['thumbnail'] ?? '';
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

class DownloadProgress {
  final double progress; // 0.0 to 1.0
  final String eta;
  final String speed;
  final String status;
  final String currentVideoTitle;
  final int currentVideoIndex;
  final int totalVideos;

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
