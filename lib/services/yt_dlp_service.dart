import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/services/api_service.dart';
import 'package:synco/services/download_service.dart';
import 'package:synco/services/url_resolver_service.dart';
import 'package:synco/utils/platform_utils.dart';

class _DetectedJsRuntime {
  final String name;
  final String path;
  const _DetectedJsRuntime(this.name, this.path);
}

class YtDlpService implements DownloadService {
  Process? _currentProcess;
  bool _cancelRequested = false;

  String _cookiesBrowser = 'none';
  String _cookiesFilePath = '';

  static const String _lastUpdateCheckKey = 'ytdlp_last_update_check';
  static const int _updateIntervalDays = 14;

  @override
  bool get isDownloading => _currentProcess != null;

  @override
  void updateConfig({
    String? cookiesBrowser,
    String? cookiesFilePath,
    String? backendUrl,
  }) {
    if (cookiesBrowser != null) _cookiesBrowser = cookiesBrowser;
    if (cookiesFilePath != null) _cookiesFilePath = cookiesFilePath;
    if (backendUrl != null) ApiService.setBaseUrl(backendUrl);
  }

  @override
  void cancelCurrentDownload() {
    _cancelRequested = true;
    if (_currentProcess != null) {
      debugPrint('Synco: Cancelling yt-dlp download...');
      _currentProcess!.kill(ProcessSignal.sigterm);
      _currentProcess = null;
    }
  }

  /// Builds an environment with full PATH for macOS, Linux, and Windows,
  /// including Deno, Node, Bun, QuickJS, Homebrew, and WinGet locations.
  Map<String, String> _getEnvWithPath() {
    final env = Map<String, String>.from(Platform.environment);
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final pathSep = Platform.isWindows ? ';' : ':';

    final List<String> extraPaths = Platform.isWindows
        ? [
            if (home.isNotEmpty) '$home\\.deno\\bin',
            if (home.isNotEmpty) '$home\\.bun\\bin',
            if (home.isNotEmpty)
              '$home\\AppData\\Local\\Microsoft\\WinGet\\Links',
            r'C:\Program Files\nodejs',
            r'C:\ProgramData\chocolatey\bin',
          ]
        : [
            if (home.isNotEmpty) '$home/.deno/bin',
            if (home.isNotEmpty) '$home/.bun/bin',
            if (home.isNotEmpty) '$home/.local/bin',
            '/opt/homebrew/bin',
            '/usr/local/bin',
            '/usr/bin',
            '/bin',
            '/usr/sbin',
            '/sbin',
          ];

    final currentPath = env['PATH'] ?? env['Path'] ?? '';
    final merged = [
      ...extraPaths.where((p) => p.isNotEmpty),
      if (currentPath.isNotEmpty) currentPath,
    ].join(pathSep);

    env['PATH'] = merged;
    if (Platform.isWindows) {
      env['Path'] = merged;
    }
    return env;
  }

  /// Detects an installed JS runtime (Deno > Node > Bun > QuickJS) so yt-dlp
  /// can solve YouTube's EJS `n` and signature challenges cleanly.
  Future<_DetectedJsRuntime?> _detectJsRuntime() async {
    final candidates = Platform.isWindows
        ? const [
            ('deno', 'deno.exe'),
            ('node', 'node.exe'),
            ('bun', 'bun.exe'),
            ('quickjs', 'qjs.exe'),
          ]
        : const [
            ('deno', 'deno'),
            ('node', 'node'),
            ('bun', 'bun'),
            ('quickjs', 'qjs'),
          ];

    final env = _getEnvWithPath();
    final finder = Platform.isWindows ? 'where' : 'which';

    for (final candidate in candidates) {
      try {
        final res = await Process.run(finder, [candidate.$2], environment: env);
        if (res.exitCode == 0) {
          final firstLine = res.stdout
              .toString()
              .split('\n')
              .map((s) => s.trim())
              .firstWhere((s) => s.isNotEmpty, orElse: () => '');
          if (firstLine.isNotEmpty) {
            return _DetectedJsRuntime(candidate.$1, firstLine);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Common yt-dlp flags that fix 2025/2026 YouTube EJS & SABR issues.
  Future<List<String>> _buildCommonFlags({bool useFallbackClients = false}) async {
    final List<String> flags = [
      '--no-warnings',
      '--ignore-config',
      '--remote-components',
      'ejs:github',
    ];

    final jsRuntime = await _detectJsRuntime();
    if (jsRuntime != null) {
      flags.addAll(['--js-runtimes', '${jsRuntime.name}:${jsRuntime.path}']);
    }

    if (useFallbackClients) {
      // Avoids SABR-only ios/mweb clients when default extraction fails
      flags.addAll([
        '--extractor-args',
        'youtube:player_client=android_vr,tv_embedded,web_safari,default',
      ]);
    }

    if (_cookiesFilePath.trim().isNotEmpty &&
        await File(_cookiesFilePath.trim()).exists()) {
      flags.addAll(['--cookies', _cookiesFilePath.trim()]);
    } else if (_cookiesBrowser.isNotEmpty && _cookiesBrowser != 'none') {
      flags.addAll(['--cookies-from-browser', _cookiesBrowser]);
    }

    return flags;
  }

  bool _shouldRetryWithFallbackClient(String stderr) {
    final lower = stderr.toLowerCase();
    return lower.contains('sabr') ||
        lower.contains('only images are available') ||
        lower.contains('requested format is not available') ||
        lower.contains('n challenge solving failed') ||
        lower.contains('signature solving failed') ||
        lower.contains('wiki/ejs');
  }

  /// Resolves clean URL or converts Spotify / Apple Music / Amazon Music /
  /// search queries into a yt-dlp `ytsearch1:` target.
  Future<({String targetUrl, ResolvedMusicTrack? resolvedTrack, ParsedMediaInput parsed})>
  _prepareTarget(String rawUrl, {ParsedMediaInput? parsed}) async {
    final effectiveParsed = parsed ?? UrlResolverService.parseInput(rawUrl);
    if (!effectiveParsed.isValid) {
      throw Exception('Could not extract a valid URL from "$rawUrl"');
    }

    if (effectiveParsed.requiresMusicSearchResolution) {
      final track = await UrlResolverService.resolveMusicTrack(effectiveParsed);
      if (track != null && track.searchQuery.isNotEmpty) {
        return (
          targetUrl: 'ytsearch1:${track.searchQuery}',
          resolvedTrack: track,
          parsed: effectiveParsed,
        );
      }
    }

    return (
      targetUrl: effectiveParsed.cleanUrl,
      resolvedTrack: null,
      parsed: effectiveParsed,
    );
  }

  Future<void> checkAndUpdateYtDlp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString(_lastUpdateCheckKey);

      bool shouldUpdate = true;
      if (lastCheckStr != null) {
        final lastCheck = DateTime.tryParse(lastCheckStr);
        if (lastCheck != null) {
          shouldUpdate =
              DateTime.now().difference(lastCheck).inDays >= _updateIntervalDays;
        }
      }

      if (shouldUpdate) {
        await updateEngine();
        await prefs.setString(
          _lastUpdateCheckKey,
          DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('Synco: Error checking yt-dlp updates: $e');
    }
  }

  @override
  Future<String> updateEngine() async {
    try {
      final result = await Process.run(
        'yt-dlp',
        const ['--update'],
        environment: _getEnvWithPath(),
      );
      final out = '${result.stdout}\n${result.stderr}'.trim();
      if (result.exitCode == 0) {
        return out.isEmpty ? 'yt-dlp is up to date.' : out;
      }
      return 'Update returned status ${result.exitCode}: $out';
    } catch (e) {
      return 'Could not run yt-dlp --update: $e';
    }
  }

  @override
  Future<EngineDiagnostics> checkDiagnostics() async {
    final env = _getEnvWithPath();
    bool ytDlpAvailable = false;
    String ytDlpVersion = 'Not installed';
    bool ffmpegAvailable = false;

    try {
      final res = await Process.run('yt-dlp', const ['--version'], environment: env);
      if (res.exitCode == 0) {
        ytDlpAvailable = true;
        ytDlpVersion = res.stdout.toString().trim();
      }
    } catch (_) {}

    try {
      final res = await Process.run('ffmpeg', const ['-version'], environment: env);
      ffmpegAvailable = res.exitCode == 0;
    } catch (_) {}

    final jsRuntime = await _detectJsRuntime();
    final backendOk = await ApiService.checkHealth();

    return EngineDiagnostics(
      ytDlpAvailable: ytDlpAvailable,
      ytDlpVersion: ytDlpVersion,
      ffmpegAvailable: ffmpegAvailable,
      jsRuntimeName: jsRuntime?.name ?? '',
      jsRuntimePath: jsRuntime?.path ?? '',
      backendReachable: backendOk,
      platformLabel: PlatformUtils.platformName,
    );
  }

  @override
  Future<VideoInfo> getVideoInfo(String url, {ParsedMediaInput? parsed}) async {
    final prepared = await _prepareTarget(url, parsed: parsed);
    final env = _getEnvWithPath();

    Future<ProcessResult> runFetch(bool fallbackClient) async {
      final common = await _buildCommonFlags(useFallbackClients: fallbackClient);
      return Process.run(
        'yt-dlp',
        [...common, '--dump-json', '--no-playlist', prepared.targetUrl],
        environment: env,
      );
    }

    var result = await runFetch(false);
    if (result.exitCode != 0 &&
        _shouldRetryWithFallbackClient(result.stderr.toString())) {
      result = await runFetch(true);
    }

    if (result.exitCode != 0) {
      final errText = result.stderr.toString().trim();
      throw Exception(
        errText.isNotEmpty ? errText : 'Failed to fetch video metadata',
      );
    }

    final rawStdout = result.stdout.toString().trim();
    final firstJsonLine = rawStdout
        .split('\n')
        .firstWhere((l) => l.trim().startsWith('{'), orElse: () => rawStdout);
    final Map<String, dynamic> json =
        jsonDecode(firstJsonLine) as Map<String, dynamic>;

    final info = VideoInfo.fromJson(json, platform: prepared.parsed.platform);
    if (prepared.resolvedTrack != null) {
      return VideoInfo(
        id: info.id,
        title: prepared.resolvedTrack!.title.isNotEmpty
            ? prepared.resolvedTrack!.title
            : info.title,
        thumbnail: prepared.resolvedTrack!.thumbnail.isNotEmpty
            ? prepared.resolvedTrack!.thumbnail
            : info.thumbnail,
        duration: info.duration,
        uploader: prepared.resolvedTrack!.sourceLabel,
        url: info.url.isNotEmpty ? info.url : prepared.targetUrl,
        platform: prepared.parsed.platform,
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
    final prepared = await _prepareTarget(url, parsed: parsed);
    final isChannel = prepared.parsed.contentType == MediaContentType.channel;
    final common = await _buildCommonFlags();
    final env = _getEnvWithPath();

    // Limit channel fetch to latest 100 videos so massive channels respond fast
    final args = <String>[
      ...common,
      '--dump-single-json',
      '--flat-playlist',
      if (isChannel) ...['--playlist-end', '100'],
      prepared.targetUrl,
    ];

    final result = await Process.run('yt-dlp', args, environment: env);
    if (result.exitCode != 0) {
      final errText = result.stderr.toString().trim();
      throw Exception(
        errText.isNotEmpty ? errText : 'Failed to fetch playlist/channel info',
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    return PlaylistInfo.fromJson(
      json,
      isChannel: isChannel,
      fallbackUrl: prepared.targetUrl,
    );
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
    final prepared = await _prepareTarget(url, parsed: parsed);

    yield* _runWithAutoFallback(
      targetUrl: prepared.targetUrl,
      outputDirectory: outputDirectory,
      isPlaylist: true,
      selectedIndices: selectedIndices,
      qualityId: qualityId,
      isAudioOnly: isAudioOnly,
      audioFormat: audioFormat,
      audioBitrate: audioBitrate,
      embedMetadata: embedMetadata,
      downloadSubtitles: downloadSubtitles,
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
    final prepared = await _prepareTarget(url, parsed: parsed);

    yield* _runWithAutoFallback(
      targetUrl: prepared.targetUrl,
      outputDirectory: outputDirectory,
      isPlaylist: false,
      qualityId: qualityId,
      isAudioOnly: isAudioOnly,
      audioFormat: audioFormat,
      audioBitrate: audioBitrate,
      embedMetadata: embedMetadata,
      downloadSubtitles: downloadSubtitles,
    );
  }

  Stream<DownloadProgress> _runWithAutoFallback({
    required String targetUrl,
    required String outputDirectory,
    required bool isPlaylist,
    List<int>? selectedIndices,
    String? qualityId,
    required bool isAudioOnly,
    required String audioFormat,
    required String audioBitrate,
    required bool embedMetadata,
    required bool downloadSubtitles,
  }) async* {
    try {
      yield* _executeYtDlp(
        targetUrl: targetUrl,
        outputDirectory: outputDirectory,
        isPlaylist: isPlaylist,
        selectedIndices: selectedIndices,
        qualityId: qualityId,
        isAudioOnly: isAudioOnly,
        audioFormat: audioFormat,
        audioBitrate: audioBitrate,
        embedMetadata: embedMetadata,
        downloadSubtitles: downloadSubtitles,
        useFallbackClients: false,
      );
    } catch (e) {
      if (_cancelRequested) rethrow;
      if (_shouldRetryWithFallbackClient(e.toString())) {
        yield const DownloadProgress(
          progress: 0.0,
          eta: '',
          speed: '',
          status: 'Retrying with fallback YouTube client...',
        );
        yield* _executeYtDlp(
          targetUrl: targetUrl,
          outputDirectory: outputDirectory,
          isPlaylist: isPlaylist,
          selectedIndices: selectedIndices,
          qualityId: qualityId,
          isAudioOnly: isAudioOnly,
          audioFormat: audioFormat,
          audioBitrate: audioBitrate,
          embedMetadata: embedMetadata,
          downloadSubtitles: downloadSubtitles,
          useFallbackClients: true,
        );
      } else {
        rethrow;
      }
    }
  }

  Stream<DownloadProgress> _executeYtDlp({
    required String targetUrl,
    required String outputDirectory,
    required bool isPlaylist,
    List<int>? selectedIndices,
    String? qualityId,
    required bool isAudioOnly,
    required String audioFormat,
    required String audioBitrate,
    required bool embedMetadata,
    required bool downloadSubtitles,
    required bool useFallbackClients,
  }) async* {
    final common = await _buildCommonFlags(
      useFallbackClients: useFallbackClients,
    );
    final List<String> args = [...common];

    if (isAudioOnly) {
      args.addAll([
        '-f',
        'ba[ext=m4a]/ba/b',
        '-x',
        '--audio-format',
        audioFormat.toLowerCase(),
        '--audio-quality',
        '${audioBitrate}K',
      ]);
      if (embedMetadata) {
        args.addAll(['--add-metadata', '--embed-thumbnail']);
      }
    } else {
      args.addAll(['--merge-output-format', 'mp4']);
      if (qualityId != null && qualityId != 'Best' && qualityId != 'Audio') {
        final height = qualityId.replaceAll(RegExp(r'[^0-9]'), '');
        if (height.isNotEmpty) {
          args.addAll([
            '-f',
            'bv*[height<=$height][ext=mp4]+ba[ext=m4a]/bv*[height<=$height]+ba/b[height<=$height]/bv*+ba/b',
          ]);
        } else {
          args.addAll(['-f', 'bv*+ba/b']);
        }
      } else {
        args.addAll(['-f', 'bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b']);
      }
      if (embedMetadata) {
        args.add('--add-metadata');
      }
      if (downloadSubtitles) {
        args.addAll(['--write-subs', '--embed-subs', '--sub-langs', 'en.*']);
      }
    }

    if (isPlaylist) {
      args.add('--yes-playlist');
      args.add('--ignore-errors');
      if (selectedIndices != null && selectedIndices.isNotEmpty) {
        args.addAll(['--playlist-items', selectedIndices.join(',')]);
      }
    } else {
      args.add('--no-playlist');
    }

    final template = isPlaylist
        ? '$outputDirectory/%(playlist_index)02d - %(title)s.%(ext)s'
        : '$outputDirectory/%(title)s.%(ext)s';

    args.addAll([
      '-o',
      template,
      '--newline',
      '--print',
      'after_move:SYNCO_FINAL_PATH:%(filepath)s',
      targetUrl,
    ]);

    debugPrint('Synco: yt-dlp args = $args');
    final process = await Process.start(
      'yt-dlp',
      args,
      environment: _getEnvWithPath(),
    );
    _currentProcess = process;

    try {
      yield* _parseProgress(process, isPlaylist: isPlaylist);
    } finally {
      _currentProcess = null;
    }
  }

  Stream<DownloadProgress> _parseProgress(
    Process process, {
    required bool isPlaylist,
  }) async* {
    final progressRegex = RegExp(
      r'\[download\]\s+(\d+\.?\d*)%\s+of\s+.*?\s+at\s+([^\s]+)\s+ETA\s+([^\s]+)',
    );
    final simpleProgressRegex = RegExp(r'\[download\]\s+(\d+\.?\d*)%');
    final playlistCounterRegex = RegExp(
      r'\[download\]\s+Downloading\s+item\s+(\d+)\s+of\s+(\d+)',
    );
    final destinationRegex = RegExp(
      r'\[download\]\s+Destination:\s+(.+)',
    );

    int currentVideoIndex = 0;
    int totalVideos = 0;
    String currentVideoTitle = '';
    String? lastFinalPath;
    bool completedAtLeastOneFile = false;

    final stderrBuffer = StringBuffer();
    final stderrSub = process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
    });

    try {
      await for (final event in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (_cancelRequested) {
          throw Exception('Download cancelled');
        }

        final line = event.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('SYNCO_FINAL_PATH:')) {
          lastFinalPath = line.substring('SYNCO_FINAL_PATH:'.length).trim();
          completedAtLeastOneFile = true;
          continue;
        }

        final playlistMatch = playlistCounterRegex.firstMatch(line);
        if (playlistMatch != null) {
          currentVideoIndex = int.tryParse(playlistMatch.group(1) ?? '') ?? 0;
          totalVideos = int.tryParse(playlistMatch.group(2) ?? '') ?? 0;
          currentVideoTitle = '';
          yield DownloadProgress(
            progress: totalVideos > 0
                ? (currentVideoIndex - 1) / totalVideos
                : 0.0,
            eta: '',
            speed: '',
            status: 'Item $currentVideoIndex of $totalVideos',
            currentVideoIndex: currentVideoIndex,
            totalVideos: totalVideos,
            currentVideoTitle: currentVideoTitle,
          );
          continue;
        }

        final destMatch = destinationRegex.firstMatch(line);
        if (destMatch != null) {
          final rawDest = destMatch.group(1)?.trim() ?? '';
          final fileName = rawDest.split(RegExp(r'[/\\]')).last;
          currentVideoTitle = fileName.replaceAll(
            RegExp(r'\.(?:f\d+\.)?(?:mp4|webm|mkv|mp3|m4a|opus|wav)$'),
            '',
          );
          yield DownloadProgress(
            progress: 0.0,
            eta: '',
            speed: '',
            status: 'Downloading...',
            currentVideoIndex: currentVideoIndex,
            totalVideos: totalVideos,
            currentVideoTitle: currentVideoTitle,
          );
          continue;
        }

        if (line.startsWith('[ExtractAudio]') || line.startsWith('[Merger]')) {
          yield DownloadProgress(
            progress: 0.96,
            eta: '',
            speed: '',
            status: line.startsWith('[ExtractAudio]')
                ? 'Converting audio...'
                : 'Merging streams...',
            currentVideoIndex: currentVideoIndex,
            totalVideos: totalVideos,
            currentVideoTitle: currentVideoTitle,
          );
          continue;
        }

        final match = progressRegex.firstMatch(line);
        if (match != null) {
          final pct = (double.tryParse(match.group(1) ?? '') ?? 0.0) / 100.0;
          yield DownloadProgress(
            progress: pct.clamp(0.0, 1.0),
            speed: match.group(2) ?? '',
            eta: match.group(3) ?? '',
            status: 'Downloading',
            currentVideoIndex: currentVideoIndex,
            totalVideos: totalVideos,
            currentVideoTitle: currentVideoTitle,
          );
          continue;
        }

        final simpleMatch = simpleProgressRegex.firstMatch(line);
        if (simpleMatch != null) {
          final pct =
              (double.tryParse(simpleMatch.group(1) ?? '') ?? 0.0) / 100.0;
          yield DownloadProgress(
            progress: pct.clamp(0.0, 1.0),
            speed: '',
            eta: '',
            status: 'Downloading',
            currentVideoIndex: currentVideoIndex,
            totalVideos: totalVideos,
            currentVideoTitle: currentVideoTitle,
          );
          continue;
        }

        if (line.contains('has already been downloaded')) {
          completedAtLeastOneFile = true;
          yield DownloadProgress(
            progress: 1.0,
            eta: '',
            speed: '',
            status: 'Already downloaded',
            currentVideoIndex: currentVideoIndex,
            totalVideos: totalVideos,
            currentVideoTitle: currentVideoTitle,
          );
        }
      }
    } finally {
      await stderrSub.cancel();
    }

    final exitCode = await process.exitCode;
    if (_cancelRequested) {
      throw Exception('Download cancelled');
    }

    if (exitCode != 0 && !(isPlaylist && completedAtLeastOneFile)) {
      final errStr = stderrBuffer.toString().trim();
      throw Exception(
        errStr.isNotEmpty
            ? errStr
            : 'yt-dlp exited with code $exitCode',
      );
    }

    yield DownloadProgress(
      progress: 1.0,
      eta: '',
      speed: '',
      status: 'Completed',
      currentVideoIndex: currentVideoIndex,
      totalVideos: totalVideos,
      currentVideoTitle: currentVideoTitle,
      outputFilePath: lastFinalPath,
    );
  }
}
