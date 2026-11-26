import 'package:synco/models/download_models.dart';
import 'package:synco/services/api_service.dart';
import 'package:synco/services/download_service.dart';
import 'package:synco/services/url_resolver_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web-safe DownloadService backed by the Synco backend API and direct
/// browser downloads. Never touches dart:io.
class WebDownloadService implements DownloadService {
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
    final reachable = await ApiService.checkHealth();
    return EngineDiagnostics(
      ytDlpAvailable: reachable,
      ytDlpVersion: reachable ? 'Connected (${ApiService.baseUrl})' : 'Backend offline',
      ffmpegAvailable: reachable,
      jsRuntimeName: reachable ? 'Server-side' : '',
      jsRuntimePath: ApiService.baseUrl,
      backendReachable: reachable,
      platformLabel: 'Web',
    );
  }

  @override
  Future<String> updateEngine() async {
    final ok = await ApiService.checkHealth();
    return ok
        ? 'Connected to Synco backend at ${ApiService.baseUrl}.'
        : 'Backend at ${ApiService.baseUrl} is not reachable. Start your Synco server or update the URL in Settings.';
  }

  @override
  Future<VideoInfo> getVideoInfo(String url, {ParsedMediaInput? parsed}) async {
    final effective = parsed ?? UrlResolverService.parseInput(url);
    if (!effective.isValid) {
      throw Exception('Could not extract a valid URL from "$url"');
    }

    String target = effective.cleanUrl;
    ResolvedMusicTrack? track;
    if (effective.requiresMusicSearchResolution) {
      track = await UrlResolverService.resolveMusicTrack(effective);
      if (track != null) {
        target = 'ytsearch1:${track.searchQuery}';
      }
    }

    final json = await ApiService.getVideoInfo(target);
    final info = VideoInfo.fromJson(json, platform: effective.platform);
    if (track != null) {
      return VideoInfo(
        id: info.id,
        title: track.title.isNotEmpty ? track.title : info.title,
        thumbnail: track.thumbnail.isNotEmpty ? track.thumbnail : info.thumbnail,
        duration: info.duration,
        uploader: track.sourceLabel,
        url: info.url.isNotEmpty ? info.url : target,
        platform: effective.platform,
        availableQualities: info.availableQualities,
      );
    }
    return info;
  }

  @override
  Future<PlaylistInfo> getPlaylistInfo(
    String url, {
    ParsedMediaInput? parsed,
  }) async {
    final effective = parsed ?? UrlResolverService.parseInput(url);
    final json = await ApiService.getPlaylistInfo(effective.cleanUrl);
    return PlaylistInfo.fromJson(
      json,
      isChannel: effective.contentType == MediaContentType.channel,
      fallbackUrl: effective.cleanUrl,
    );
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
    try {
      final effective = parsed ?? UrlResolverService.parseInput(url);
      String target = effective.cleanUrl;
      if (effective.requiresMusicSearchResolution) {
        final track = await UrlResolverService.resolveMusicTrack(effective);
        if (track != null) target = 'ytsearch1:${track.searchQuery}';
      }

      yield const DownloadProgress(
        progress: 0.25,
        eta: '',
        speed: '',
        status: 'Requesting stream from server...',
      );

      final cleanQuality =
          (qualityId ?? '1080').replaceAll(RegExp(r'[^0-9]'), '');
      final result = await ApiService.getDownloadUrl(
        target,
        quality: cleanQuality.isEmpty ? '1080' : cleanQuality,
        isAudioOnly: isAudioOnly,
        audioFormat: audioFormat,
      );

      if (_cancelRequested) {
        throw Exception('Download cancelled');
      }

      final directUrl = result['downloadUrl']?.toString() ??
          result['url']?.toString() ??
          '';
      if (directUrl.isEmpty) {
        throw Exception('Backend did not return a downloadable URL.');
      }

      final uri = Uri.tryParse(directUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      yield DownloadProgress(
        progress: 1.0,
        eta: '',
        speed: '',
        status: 'Sent to browser downloads',
        outputFilePath: directUrl,
      );
    } finally {
      _isDownloading = false;
    }
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
    final info = await getPlaylistInfo(url, parsed: parsed);
    final entries = info.entries;
    final indices = selectedIndices ??
        List<int>.generate(entries.length, (index) => index + 1);

    for (int i = 0; i < indices.length; i++) {
      if (_cancelRequested) throw Exception('Download cancelled');
      final idx = indices[i] - 1;
      if (idx < 0 || idx >= entries.length) continue;
      final item = entries[idx];
      yield DownloadProgress(
        progress: i / indices.length,
        eta: '',
        speed: '',
        status: 'Item ${i + 1} of ${indices.length}',
        currentVideoIndex: i + 1,
        totalVideos: indices.length,
        currentVideoTitle: item.title,
      );
      await for (final _ in downloadVideo(
        item.url,
        outputDirectory,
        qualityId: qualityId,
        isAudioOnly: isAudioOnly,
        audioFormat: audioFormat,
        audioBitrate: audioBitrate,
      )) {}
    }

    yield DownloadProgress(
      progress: 1.0,
      eta: '',
      speed: '',
      status: 'Sent ${indices.length} items to browser',
      currentVideoIndex: indices.length,
      totalVideos: indices.length,
    );
  }
}
