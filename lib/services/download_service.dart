import 'package:synco/models/download_models.dart';

abstract class DownloadService {
  Future<VideoInfo> getVideoInfo(String url);
  Future<PlaylistInfo> getPlaylistInfo(String url);

  Stream<DownloadProgress> downloadVideo(
    String url,
    String outputDirectory, {
    String? qualityId,
    bool isAudioOnly = false,
  });

  Stream<DownloadProgress> downloadPlaylist(
    String url,
    String outputDirectory, {
    List<int>? selectedIndices,
    String? qualityId,
    bool isAudioOnly = false,
  });

  void cancelCurrentDownload();
  bool get isDownloading;
}
