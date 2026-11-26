import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/services/api_service.dart';
import 'package:synco/services/download_service.dart';
import 'package:synco/services/mobile_download_service.dart';
import 'package:synco/services/url_resolver_service.dart';
import 'package:synco/services/web_download_service.dart';
import 'package:synco/services/yt_dlp_service.dart';
import 'package:synco/utils/platform_utils.dart';

class AppStateProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  late final DownloadService _downloadService;

  static const String _historyPrefsKey = 'synco_download_history_v2';
  static const String _queuePrefsKey = 'synco_download_queue_v2';

  // Appearance & Mode
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = const Color(0xFF0A84FF); // Vibrant Synco Blue
  AppMediaMode _mediaMode = AppMediaMode.video;

  // Preferences
  String? _downloadPath;
  bool _incognitoMode = false;
  bool _autoDetectClipboard = true;
  bool _autoCreateSubfolders = true;
  bool _embedMetadata = true;
  String _defaultVideoQuality = '1080p';
  String _defaultAudioFormat = 'mp3';
  String _defaultAudioBitrate = '320';
  String _cookiesBrowser = 'none';
  String _cookiesFilePath = '';
  String _backendUrl = ApiService.defaultBaseUrl;

  // Queue & History
  final List<DownloadTask> _queue = [];
  final List<DownloadTask> _history = [];
  bool _isProcessingQueue = false;
  String? _activeTaskId;
  StreamSubscription<DownloadProgress>? _activeSubscription;

  // Diagnostics
  EngineDiagnostics? _diagnostics;
  bool _isCheckingDiagnostics = false;

  AppStateProvider(this.prefs, {DownloadService? downloadServiceOverride}) {
    _downloadService = downloadServiceOverride ?? _createPlatformService();
    _loadFromPrefs();
    _syncServiceConfig();
  }

  DownloadService _createPlatformService() {
    if (kIsWeb) return WebDownloadService();
    if (PlatformUtils.isDesktop) return YtDlpService();
    return MobileDownloadService();
  }

  // Getters
  DownloadService get downloadService => _downloadService;
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  AppMediaMode get mediaMode => _mediaMode;
  String? get downloadPath => _downloadPath;
  bool get incognitoMode => _incognitoMode;
  bool get autoDetectClipboard => _autoDetectClipboard;
  bool get autoCreateSubfolders => _autoCreateSubfolders;
  bool get embedMetadata => _embedMetadata;
  String get defaultVideoQuality => _defaultVideoQuality;
  String get defaultAudioFormat => _defaultAudioFormat;
  String get defaultAudioBitrate => _defaultAudioBitrate;
  String get cookiesBrowser => _cookiesBrowser;
  String get cookiesFilePath => _cookiesFilePath;
  String get backendUrl => _backendUrl;

  List<DownloadTask> get queue => List.unmodifiable(_queue);
  List<DownloadTask> get history => List.unmodifiable(_history);
  EngineDiagnostics? get diagnostics => _diagnostics;
  bool get isCheckingDiagnostics => _isCheckingDiagnostics;

  int get activeCount => _queue.where((t) => t.isActive).length;
  int get failedCount =>
      _queue.where((t) => t.status == DownloadTaskStatus.failed).length;
  int get completedCount =>
      _queue.where((t) => t.status == DownloadTaskStatus.completed).length;

  void _loadFromPrefs() {
    final savedTheme = prefs.getString('themeMode');
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      final legacyDark = prefs.getBool('isDark');
      _themeMode = (legacyDark == false) ? ThemeMode.light : ThemeMode.dark;
    }

    final colorVal = prefs.getInt('accentColor');
    if (colorVal != null) {
      _accentColor = Color(colorVal);
    }

    _downloadPath = prefs.getString('downloadPath');
    _incognitoMode = prefs.getBool('incognitoMode') ?? false;
    _autoDetectClipboard = prefs.getBool('autoDetectClipboard') ?? true;
    _autoCreateSubfolders = prefs.getBool('autoCreateSubfolders') ?? true;
    _embedMetadata = prefs.getBool('embedMetadata') ?? true;
    _defaultVideoQuality = prefs.getString('defaultVideoQuality') ?? '1080p';
    _defaultAudioFormat = prefs.getString('defaultAudioFormat') ?? 'mp3';
    _defaultAudioBitrate = prefs.getString('defaultAudioBitrate') ?? '320';
    _cookiesBrowser = prefs.getString('cookiesBrowser') ?? 'none';
    _cookiesFilePath = prefs.getString('cookiesFilePath') ?? '';
    _backendUrl = prefs.getString('backendUrl') ?? ApiService.defaultBaseUrl;

    _loadJsonTaskList(_historyPrefsKey, _history);
    _loadJsonTaskList(_queuePrefsKey, _queue, resetActiveToFailed: true);
  }

  void _loadJsonTaskList(
    String key,
    List<DownloadTask> target, {
    bool resetActiveToFailed = false,
  }) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          var task = DownloadTask.fromJson(item);
          if (resetActiveToFailed && task.isActive) {
            task = task.copyWith(
              status: DownloadTaskStatus.cancelled,
              statusMessage: 'Interrupted when app closed',
            );
          }
          target.add(task);
        }
      }
    } catch (e) {
      debugPrint('Synco: Failed to load saved list ($key): $e');
    }
  }

  Future<void> _persistHistory() async {
    try {
      final trimmed = _history.take(200).map((e) => e.toJson()).toList();
      await prefs.setString(_historyPrefsKey, jsonEncode(trimmed));
    } catch (e) {
      debugPrint('Synco: Persist history error: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final trimmed = _queue.take(150).map((e) => e.toJson()).toList();
      await prefs.setString(_queuePrefsKey, jsonEncode(trimmed));
    } catch (e) {
      debugPrint('Synco: Persist queue error: $e');
    }
  }

  void _syncServiceConfig() {
    _downloadService.updateConfig(
      cookiesBrowser: _cookiesBrowser,
      cookiesFilePath: _cookiesFilePath,
      backendUrl: _backendUrl,
    );
  }

  // Settings Mutators
  void setMediaMode(AppMediaMode mode) {
    if (_mediaMode == mode) return;
    _mediaMode = mode;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    unawaited(prefs.setString('themeMode', mode.name));
    unawaited(prefs.setBool('isDark', mode == ThemeMode.dark));
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    unawaited(prefs.setInt('accentColor', color.toARGB32()));
    notifyListeners();
  }

  void setDownloadPath(String path) {
    _downloadPath = path.trim().isEmpty ? null : path.trim();
    if (_downloadPath == null) {
      unawaited(prefs.remove('downloadPath'));
    } else {
      unawaited(prefs.setString('downloadPath', _downloadPath!));
    }
    notifyListeners();
  }

  void toggleIncognito(bool value) {
    _incognitoMode = value;
    unawaited(prefs.setBool('incognitoMode', value));
    notifyListeners();
  }

  void toggleAutoDetectClipboard(bool value) {
    _autoDetectClipboard = value;
    unawaited(prefs.setBool('autoDetectClipboard', value));
    notifyListeners();
  }

  void toggleAutoCreateSubfolders(bool value) {
    _autoCreateSubfolders = value;
    unawaited(prefs.setBool('autoCreateSubfolders', value));
    notifyListeners();
  }

  void toggleEmbedMetadata(bool value) {
    _embedMetadata = value;
    unawaited(prefs.setBool('embedMetadata', value));
    notifyListeners();
  }

  void setDefaultVideoQuality(String quality) {
    _defaultVideoQuality = quality;
    unawaited(prefs.setString('defaultVideoQuality', quality));
    notifyListeners();
  }

  void setDefaultAudioFormat(String format) {
    _defaultAudioFormat = format;
    unawaited(prefs.setString('defaultAudioFormat', format));
    notifyListeners();
  }

  void setDefaultAudioBitrate(String bitrate) {
    _defaultAudioBitrate = bitrate;
    unawaited(prefs.setString('defaultAudioBitrate', bitrate));
    notifyListeners();
  }

  void setCookiesBrowser(String browser) {
    _cookiesBrowser = browser;
    unawaited(prefs.setString('cookiesBrowser', browser));
    _syncServiceConfig();
    notifyListeners();
  }

  void setCookiesFilePath(String path) {
    _cookiesFilePath = path.trim();
    unawaited(prefs.setString('cookiesFilePath', _cookiesFilePath));
    _syncServiceConfig();
    notifyListeners();
  }

  void setBackendUrl(String url) {
    _backendUrl = url.trim().isEmpty ? ApiService.defaultBaseUrl : url.trim();
    unawaited(prefs.setString('backendUrl', _backendUrl));
    _syncServiceConfig();
    notifyListeners();
  }

  Future<void> refreshDiagnostics() async {
    _isCheckingDiagnostics = true;
    notifyListeners();
    try {
      _diagnostics = await _downloadService.checkDiagnostics();
    } finally {
      _isCheckingDiagnostics = false;
      notifyListeners();
    }
  }

  Future<String> runEngineUpdate() async {
    final message = await _downloadService.updateEngine();
    await refreshDiagnostics();
    return message;
  }

  // Queue Management
  void enqueueConfiguredDownload({
    required String rawInput,
    required ParsedMediaInput parsed,
    required DownloadConfiguration config,
    VideoInfo? videoInfo,
    PlaylistInfo? playlistInfo,
  }) {
    final isCollection = playlistInfo != null || parsed.isCollection;
    final title = playlistInfo?.title ??
        videoInfo?.title ??
        parsed.searchHint ??
        parsed.displayDomain;
    final subtitle = playlistInfo != null
        ? '${playlistInfo.isChannel ? "Channel" : "Playlist"} • ${config.selectedIndices?.length ?? playlistInfo.entries.length} items'
        : (videoInfo?.uploader.isNotEmpty == true
            ? videoInfo!.uploader
            : parsed.displayDomain);
    final thumbnail = playlistInfo?.thumbnail ?? videoInfo?.thumbnail ?? '';

    final task = DownloadTask(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      rawInput: rawInput,
      resolvedUrl: parsed.cleanUrl.isNotEmpty ? parsed.cleanUrl : rawInput,
      title: title.isNotEmpty ? title : 'Media Download',
      subtitle: subtitle,
      thumbnail: thumbnail,
      platform: parsed.platform,
      contentType: isCollection
          ? (playlistInfo?.isChannel == true
              ? MediaContentType.channel
              : MediaContentType.playlist)
          : (config.isAudioOnly
              ? MediaContentType.audio
              : MediaContentType.video),
      mode: config.isAudioOnly ? AppMediaMode.music : AppMediaMode.video,
      qualityLabel: config.badgeLabel,
      qualityId: config.qualityId,
      audioFormat: config.audioFormat,
      audioBitrate: config.audioBitrate,
      isAudioOnly: config.isAudioOnly,
      embedMetadata: config.embedMetadata,
      downloadSubtitles: config.downloadSubtitles,
      selectedIndices: config.selectedIndices,
      status: DownloadTaskStatus.queued,
      statusMessage: 'Queued',
      totalItems: playlistInfo != null
          ? (config.selectedIndices?.length ?? playlistInfo.entries.length)
          : 1,
      createdAt: DateTime.now(),
    );

    _queue.insert(0, task);
    unawaited(_persistQueue());
    notifyListeners();
    unawaited(_processNextInQueue());
  }

  /// Quick one-tap download (used by Clipboard Banner & Music Quick Download)
  /// without blocking the user in a modal first.
  void enqueueQuickDownload(String rawInput, {AppMediaMode? modeOverride}) {
    final mode = modeOverride ?? _mediaMode;
    final parsed = UrlResolverService.parseInput(rawInput, preferredMode: mode);
    if (!parsed.isValid) {
      final err = UrlResolverService.formatFriendlyError(
        'Could not extract a valid URL from "$rawInput"',
      );
      _queue.insert(
        0,
        DownloadTask(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          rawInput: rawInput,
          resolvedUrl: rawInput,
          title: rawInput.trim().isEmpty ? 'Invalid Input' : rawInput.trim(),
          subtitle: 'Invalid URL',
          thumbnail: '',
          platform: MediaSourcePlatform.generic,
          contentType: MediaContentType.video,
          mode: mode,
          qualityLabel: mode == AppMediaMode.music
              ? _defaultAudioFormat.toUpperCase()
              : _defaultVideoQuality.toUpperCase(),
          qualityId: _defaultVideoQuality,
          audioFormat: _defaultAudioFormat,
          audioBitrate: _defaultAudioBitrate,
          isAudioOnly: mode == AppMediaMode.music,
          embedMetadata: _embedMetadata,
          downloadSubtitles: false,
          status: DownloadTaskStatus.failed,
          statusMessage: 'Failed',
          errorSummary: err.summary,
          errorDetails: err.details,
          errorFixHint: err.fixHint,
          isEngineFixable: err.isEngineFixable,
          createdAt: DateTime.now(),
        ),
      );
      unawaited(_persistQueue());
      notifyListeners();
      return;
    }

    final isAudio = mode == AppMediaMode.music ||
        parsed.platform.isDrmMusicService ||
        parsed.platform == MediaSourcePlatform.youtubeMusic;

    final config = DownloadConfiguration(
      qualityId: isAudio ? 'Audio' : _defaultVideoQuality,
      isAudioOnly: isAudio,
      audioFormat: _defaultAudioFormat,
      audioBitrate: _defaultAudioBitrate,
      embedMetadata: _embedMetadata,
    );

    enqueueConfiguredDownload(
      rawInput: rawInput,
      parsed: parsed,
      config: config,
    );
  }

  Future<void> _processNextInQueue() async {
    if (_isProcessingQueue) return;

    // Pick oldest queued item (FIFO) so user queue executes in order
    final nextIndex = _queue.lastIndexWhere(
      (t) => t.status == DownloadTaskStatus.queued,
    );
    if (nextIndex == -1) return;

    _isProcessingQueue = true;
    final taskId = _queue[nextIndex].id;
    _activeTaskId = taskId;

    try {
      await _executeTask(taskId);
    } finally {
      _activeTaskId = null;
      _isProcessingQueue = false;
      unawaited(_persistQueue());
      notifyListeners();
      // Continue with remaining queued items
      if (_queue.any((t) => t.status == DownloadTaskStatus.queued)) {
        unawaited(_processNextInQueue());
      }
    }
  }

  Future<void> _executeTask(String taskId) async {
    var task = _findTask(taskId);
    if (task == null) return;

    final parsed = UrlResolverService.parseInput(
      task.rawInput,
      preferredMode: task.mode,
    );

    // 1. Resolve missing metadata (for quick downloads & Spotify/Apple/Amazon Music)
    if (task.thumbnail.isEmpty ||
        task.title == parsed.displayDomain ||
        parsed.requiresMusicSearchResolution) {
      _updateTask(
        taskId,
        (t) => t.copyWith(
          status: DownloadTaskStatus.resolving,
          statusMessage: parsed.requiresMusicSearchResolution
              ? 'Matching track on YouTube...'
              : 'Fetching metadata...',
          clearError: true,
        ),
      );

      try {
        if (parsed.isCollection) {
          final info = await _downloadService.getPlaylistInfo(
            task.rawInput,
            parsed: parsed,
          );
          _updateTask(
            taskId,
            (t) => t.copyWith(
              title: info.title,
              subtitle:
                  '${info.isChannel ? "Channel" : "Playlist"} • ${info.entries.length} items',
              thumbnail: info.thumbnail,
              totalItems: info.entries.length,
            ),
          );
        } else {
          final info = await _downloadService.getVideoInfo(
            task.rawInput,
            parsed: parsed,
          );
          _updateTask(
            taskId,
            (t) => t.copyWith(
              title: info.title,
              subtitle: info.uploader.isNotEmpty
                  ? info.uploader
                  : parsed.displayDomain,
              thumbnail: info.thumbnail,
              resolvedUrl: info.url.isNotEmpty ? info.url : t.resolvedUrl,
            ),
          );
        }
      } catch (e) {
        // If metadata lookup failed on a DRM music link, abort cleanly;
        // otherwise continue to let the download stream attempt fallback clients.
        if (parsed.requiresMusicSearchResolution) {
          _markTaskFailed(taskId, e.toString());
          return;
        }
      }
    }

    task = _findTask(taskId);
    if (task == null || task.status == DownloadTaskStatus.cancelled) return;

    // 2. Prepare destination folder
    final outputDir = await PlatformUtils.prepareOutputDirectory(
      customBasePath: _downloadPath,
      autoCreateSubfolders: _autoCreateSubfolders,
      collectionName: task.contentType == MediaContentType.playlist ||
              task.contentType == MediaContentType.channel
          ? task.title
          : null,
      isChannel: task.contentType == MediaContentType.channel,
    );

    _updateTask(
      taskId,
      (t) => t.copyWith(
        status: DownloadTaskStatus.downloading,
        statusMessage: 'Starting download...',
        progress: 0.0,
        outputPath: outputDir,
        clearError: true,
      ),
    );

    // 3. Execute Download Stream
    final Stream<DownloadProgress> stream =
        (task.contentType == MediaContentType.playlist ||
                task.contentType == MediaContentType.channel)
            ? _downloadService.downloadPlaylist(
                task.rawInput,
                outputDir,
                selectedIndices: task.selectedIndices,
                qualityId: task.qualityId,
                isAudioOnly: task.isAudioOnly,
                audioFormat: task.audioFormat,
                audioBitrate: task.audioBitrate,
                embedMetadata: task.embedMetadata,
                downloadSubtitles: task.downloadSubtitles,
                parsed: parsed,
              )
            : _downloadService.downloadVideo(
                task.rawInput,
                outputDir,
                qualityId: task.qualityId,
                isAudioOnly: task.isAudioOnly,
                audioFormat: task.audioFormat,
                audioBitrate: task.audioBitrate,
                embedMetadata: task.embedMetadata,
                downloadSubtitles: task.downloadSubtitles,
                parsed: parsed,
              );

    final completer = Completer<void>();
    String? finalOutputPath;

    await _activeSubscription?.cancel();
    _activeSubscription = stream.listen(
      (event) {
        if (event.outputFilePath != null && event.outputFilePath!.isNotEmpty) {
          finalOutputPath = event.outputFilePath;
        }
        _updateTask(
          taskId,
          (t) => t.copyWith(
            status: DownloadTaskStatus.downloading,
            progress: event.progress > 0 ? event.progress : t.progress,
            speed: event.speed,
            eta: event.eta,
            statusMessage: event.status,
            currentItemIndex: event.currentVideoIndex > 0
                ? event.currentVideoIndex
                : t.currentItemIndex,
            totalItems:
                event.totalVideos > 0 ? event.totalVideos : t.totalItems,
            currentItemTitle: event.currentVideoTitle.isNotEmpty
                ? event.currentVideoTitle
                : t.currentItemTitle,
            outputPath: finalOutputPath ?? t.outputPath,
          ),
        );
      },
      onError: (Object error) {
        final current = _findTask(taskId);
        if (current != null && current.status != DownloadTaskStatus.cancelled) {
          _markTaskFailed(taskId, error.toString());
        }
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        final current = _findTask(taskId);
        if (current != null &&
            current.status != DownloadTaskStatus.failed &&
            current.status != DownloadTaskStatus.cancelled) {
          final completedTask = current.copyWith(
            status: DownloadTaskStatus.completed,
            progress: 1.0,
            speed: '',
            eta: '',
            statusMessage: 'Saved',
            outputPath: finalOutputPath ?? outputDir,
            completedAt: DateTime.now(),
            clearError: true,
          );
          _replaceTask(taskId, completedTask);

          if (!_incognitoMode) {
            _history.removeWhere((h) => h.id == completedTask.id);
            _history.insert(0, completedTask);
            unawaited(_persistHistory());
          }
        }
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
    await _activeSubscription?.cancel();
    _activeSubscription = null;
  }

  void _markTaskFailed(String taskId, String rawError) {
    final friendly = UrlResolverService.formatFriendlyError(rawError);
    _updateTask(
      taskId,
      (t) => t.copyWith(
        status: DownloadTaskStatus.failed,
        speed: '',
        eta: '',
        statusMessage: 'Failed',
        errorSummary: friendly.summary,
        errorDetails: friendly.details,
        errorFixHint: friendly.fixHint,
        isEngineFixable: friendly.isEngineFixable,
      ),
    );
  }

  void cancelTask(String taskId) {
    final task = _findTask(taskId);
    if (task == null) return;

    if (_activeTaskId == taskId) {
      _downloadService.cancelCurrentDownload();
      unawaited(_activeSubscription?.cancel());
    }

    _updateTask(
      taskId,
      (t) => t.copyWith(
        status: DownloadTaskStatus.cancelled,
        speed: '',
        eta: '',
        statusMessage: 'Cancelled',
      ),
    );
    unawaited(_persistQueue());
  }

  void retryTask(String taskId) {
    _updateTask(
      taskId,
      (t) => t.copyWith(
        status: DownloadTaskStatus.queued,
        progress: 0.0,
        speed: '',
        eta: '',
        statusMessage: 'Queued',
        clearError: true,
      ),
    );
    unawaited(_persistQueue());
    unawaited(_processNextInQueue());
  }

  void retryAllFailed() {
    bool changed = false;
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].status == DownloadTaskStatus.failed ||
          _queue[i].status == DownloadTaskStatus.cancelled) {
        _queue[i] = _queue[i].copyWith(
          status: DownloadTaskStatus.queued,
          progress: 0.0,
          speed: '',
          eta: '',
          statusMessage: 'Queued',
          clearError: true,
        );
        changed = true;
      }
    }
    if (changed) {
      unawaited(_persistQueue());
      notifyListeners();
      unawaited(_processNextInQueue());
    }
  }

  void removeTask(String taskId) {
    if (_activeTaskId == taskId) {
      cancelTask(taskId);
    }
    _queue.removeWhere((t) => t.id == taskId);
    unawaited(_persistQueue());
    notifyListeners();
  }

  void clearCompletedTasks() {
    _queue.removeWhere((t) => t.status == DownloadTaskStatus.completed);
    unawaited(_persistQueue());
    notifyListeners();
  }

  void clearAllTasks() {
    if (_activeTaskId != null) {
      _downloadService.cancelCurrentDownload();
      unawaited(_activeSubscription?.cancel());
    }
    _queue.clear();
    unawaited(_persistQueue());
    notifyListeners();
  }

  // History Management
  void removeHistoryItem(String taskId) {
    _history.removeWhere((h) => h.id == taskId);
    unawaited(_persistHistory());
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    unawaited(_persistHistory());
    notifyListeners();
  }

  DownloadTask? _findTask(String id) {
    for (final t in _queue) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _updateTask(String id, DownloadTask Function(DownloadTask) updater) {
    final idx = _queue.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _queue[idx] = updater(_queue[idx]);
    notifyListeners();
  }

  void _replaceTask(String id, DownloadTask replacement) {
    final idx = _queue.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _queue[idx] = replacement;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_activeSubscription?.cancel());
    super.dispose();
  }
}
