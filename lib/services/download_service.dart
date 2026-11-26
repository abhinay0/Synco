import 'package:synco/models/download_models.dart';

abstract class DownloadService {
  Future<VideoInfo> getVideoInfo(String url, {ParsedMediaInput? parsed});

  Future<PlaylistInfo> getPlaylistInfo(String url, {ParsedMediaInput? parsed});

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
  });

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
  });

  void cancelCurrentDownload();

  bool get isDownloading;

  void updateConfig({
    String? cookiesBrowser,
    String? cookiesFilePath,
    String? backendUrl,
  }) {}

  Future<EngineDiagnostics> checkDiagnostics();

  Future<String> updateEngine();
}
