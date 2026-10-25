import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:synco/services/native_ytdlp_bridge.dart';
import '../services/mobile_download_service.dart';
import 'argument_builder.dart';
import 'download_task.dart';
import 'persistence_manager.dart';

class DownloadEngine extends ChangeNotifier {
  static const int maxConcurrency = 3;

  final List<DownloadTask> _tasks = [];
  final Map<String, Process> _runningProcesses = {};

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.isRunning).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.isDone).toList();

  int get runningCount =>
      _tasks.where((t) => t.status == TaskStatus.running || t.status == TaskStatus.fetchingInfo).length;

  DownloadEngine() {
    _initializeFromBackup();
  }

  Future<void> _initializeFromBackup() async {
    final restored = await PersistenceManager.restoreQueueBackup();
    if (restored.isNotEmpty) {
      _tasks.addAll(restored);
      notifyListeners();
    }
  }

  void _persistQueue() {
    PersistenceManager.saveQueueBackup(_tasks);
  }

  /// Add a task to queue
  void enqueue(DownloadTask task) {
    _tasks.insert(0, task);
    _persistQueue();
    notifyListeners();
    _processNextQueueItem();
  }

  /// Cancel a task
  void cancelTask(String taskId) {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      task.cancel();

      // Kill running process if any
      final process = _runningProcesses.remove(taskId);
      if (process != null) {
        try {
          process.kill(ProcessSignal.sigterm);
        } catch (_) {}
      }

      _persistQueue();
      notifyListeners();
      _processNextQueueItem();
    }
  }

  /// Restart a canceled or failed task
  void restartTask(String taskId) {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      task.setStatus(TaskStatus.idle, message: 'Restarting...');
      _persistQueue();
      notifyListeners();
      _processNextQueueItem();
    }
  }

  /// Remove task from list
  void removeTask(String taskId) {
    cancelTask(taskId);
    _tasks.removeWhere((t) => t.id == taskId);
    _persistQueue();
    notifyListeners();
  }

  /// Process queue with concurrency throttling (MAX_CONCURRENCY = 3)
  void _processNextQueueItem() {
    if (runningCount >= maxConcurrency) return;

    // Find first idle task
    final idleTask = _tasks.firstWhere(
      (t) => t.status == TaskStatus.idle,
      orElse: () => DownloadTask(
        id: '',
        url: '',
        options: const DownloadOptions(),
      ),
    );

    if (idleTask.id.isNotEmpty) {
      _executeTask(idleTask);
    }
  }

  /// Execute download task using yt-dlp or native pipeline
  Future<void> _executeTask(DownloadTask task) async {
    task.setStatus(TaskStatus.running, message: 'Starting engine...');
    notifyListeners();
    _persistQueue();

    // Determine download directory
    final downloadDir = await _getEffectiveDownloadDirectory();

    // Determine effective target URL (matches Spotify tracks to YouTube Music streams)
    String targetUrl = task.url;
    if (task.url.contains('spotify.com/') || task.url.startsWith('spotify:')) {
      targetUrl = 'ytsearch1:${task.title} audio';
    }

    // Build arguments mirroring Seal's dynamic builder
    final args = DynamicArgumentBuilder.buildDownloadArguments(
      targetUrl,
      downloadDir,
      task.options,
    );

    try {
      String? lastOutputFilename;

      if (!kIsWeb && Platform.isAndroid) {
        debugPrint(
            'DownloadEngine: Executing native youtubedl-android on Android');
        task.onCancel = () {
          NativeYtDlpBridge.cancel(task.id);
        };

        final result = await NativeYtDlpBridge.execute(
          taskId: task.id,
          url: targetUrl,
          args: args,
          onProgress: (progress, etaSeconds, line) {
            _parseOutputLine(task, line, (foundFile) {
              lastOutputFilename = foundFile;
            });

            // If progress parsed directly from youtubedl-android
            if (progress > 0) {
              final etaStr = etaSeconds > 0
                  ? '${(etaSeconds ~/ 60).toString().padLeft(2, '0')}:${(etaSeconds % 60).toString().padLeft(2, '0')}'
                  : '';
              task.updateProgress(
                progress: (progress / 100.0).clamp(0.0, 1.0),
                eta: etaStr,
                statusMessage: 'Downloading ${progress.toStringAsFixed(1)}%',
              );
            }
          },
        );

        if (result.exitCode == 0) {
          final finalPath = lastOutputFilename ?? '$downloadDir/${task.title}';
          task.markCompleted(finalPath);
          await NativeYtDlpBridge.scanFile(finalPath);

          // Record in history
          await PersistenceManager.addHistoryItem(
            HistoryItem(
              id: task.id,
              title: task.title,
              uploader: task.uploader,
              url: task.url,
              thumbnailUrl: task.thumbnailUrl,
              filePath: finalPath,
              isAudioOnly: task.options.isAudioOnly,
            ),
          );
        } else if (!task.isCanceled) {
          // If this is YouTube and yt-dlp failed (e.g. Bot check / Precondition failed / 400 Bad Request / Please sign in)
          if (_isYouTubeUrl(task.url) || _isYouTubeUrl(targetUrl)) {
            debugPrint('DownloadEngine: yt-dlp hit YouTube restrictions. Falling back seamlessly to native stream engine...');
            task.updateProgress(progress: 0.05, statusMessage: 'Connecting via direct stream...');
            final fallbackSuccess = await _executeFallbackDownload(task, downloadDir);
            if (fallbackSuccess) {
              return;
            }
          }

          task.setStatus(
            TaskStatus.error,
            message: result.stderr.isNotEmpty
                ? result.stderr
                : 'Download failed (Code ${result.exitCode})',
            error: result.stderr,
          );
        }
      } else {
        final env = _getEnvironmentWithToolPaths();

        debugPrint('DownloadEngine: Executing yt-dlp with ${args.length} args');
        final process = await Process.start(
          'yt-dlp',
          args,
          environment: env,
          runInShell: true,
        );

        _runningProcesses[task.id] = process;
        task.onCancel = () {
          try {
            process.kill(ProcessSignal.sigterm);
          } catch (_) {}
        };

        // Parse stdout for progress updates
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          debugPrint('[yt-dlp] $line');
          _parseOutputLine(task, line, (foundFile) {
            lastOutputFilename = foundFile;
          });
        });

        // Listen to stderr for potential warnings/errors
        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          debugPrint('[yt-dlp err] $line');
        });

        final exitCode = await process.exitCode;
        _runningProcesses.remove(task.id);

        if (exitCode == 0) {
          final finalPath = lastOutputFilename ?? '$downloadDir/${task.title}';
          task.markCompleted(finalPath);

          // Record in history
          await PersistenceManager.addHistoryItem(
            HistoryItem(
              id: task.id,
              title: task.title,
              uploader: task.uploader,
              url: task.url,
              thumbnailUrl: task.thumbnailUrl,
              filePath: finalPath,
              isAudioOnly: task.options.isAudioOnly,
            ),
          );
        } else if (!task.isCanceled) {
          task.setStatus(
            TaskStatus.error,
            message: 'Process exited with code $exitCode',
            error: 'Download failed ($exitCode)',
          );
        }
      }
    } catch (e) {
      _runningProcesses.remove(task.id);
      if (!task.isCanceled) {
        debugPrint('DownloadEngine error: $e');
        task.setStatus(
          TaskStatus.error,
          message: 'Execution error: $e',
          error: e.toString(),
        );
      }
    } finally {
      _persistQueue();
      notifyListeners();
      _processNextQueueItem();
    }
  }

  /// Parse stdout lines for percentage, speed, ETA, and destination filename
  void _parseOutputLine(
    DownloadTask task,
    String line,
    Function(String) onFoundFile,
  ) {
    // Check destination file path
    // [download] Destination: /path/to/file.ext
    // [Merger] Merging formats into "/path/to/file.mp4"
    if (line.contains('[download] Destination:') || line.contains('Merging formats into')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final path = parts.sublist(1).join(':').trim().replaceAll('"', '');
        onFoundFile(path);
      }
    }

    // Progress line:
    // [download]  45.2% of ~  24.50MiB at    3.21MiB/s ETA 00:04
    final progressRegex = RegExp(
      r'\[download\]\s+(\d+\.?\d*)%\s+of\s+~?\s*([\d\.]+\w+)\s+at\s+([\d\.]+\w+/s)\s+ETA\s+(\d+:\d+)',
    );

    final match = progressRegex.firstMatch(line);
    if (match != null) {
      final percent = double.tryParse(match.group(1) ?? '0') ?? 0.0;
      final speed = match.group(3) ?? '';
      final eta = match.group(4) ?? '';

      task.updateProgress(
        progress: percent / 100.0,
        speed: speed,
        eta: eta,
        statusMessage: 'Downloading ${(percent).toStringAsFixed(1)}%',
      );
    } else if (line.contains('[ExtractAudio]')) {
      task.setStatus(TaskStatus.running, message: 'Extracting audio & tags...');
    } else if (line.contains('[Merger]')) {
      task.setStatus(TaskStatus.running, message: 'Merging audio & video...');
    }
  }

  /// Environment PATH setup helper to ensure yt-dlp & ffmpeg binaries are found
  Map<String, String> _getEnvironmentWithToolPaths() {
    final env = Map<String, String>.from(Platform.environment);
    final additionalPaths = [
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
      if (Platform.environment['HOME'] != null)
        '${Platform.environment['HOME']}/.local/bin',
    ].join(':');

    final currentPath = env['PATH'] ?? '';
    env['PATH'] = '$additionalPaths:$currentPath';
    return env;
  }

  Future<String> _getEffectiveDownloadDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final nativeDir = await NativeYtDlpBridge.getDownloadDirectory();
      if (nativeDir != null && nativeDir.isNotEmpty) {
        return nativeDir;
      }
    }

    // Default to Downloads on desktop, or platform storage
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      final downloads = '$home/Downloads';
      if (await Directory(downloads).exists()) return downloads;
    }
    return Directory.current.path;
  }

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.startsWith('ytsearch');
  }

  Future<bool> _executeFallbackDownload(
      DownloadTask task, String downloadDir) async {
    try {
      final mobileService = MobileDownloadService();
      final stream = mobileService.downloadVideo(
        task.url,
        downloadDir,
        qualityId: task.options.resolution,
        isAudioOnly: task.options.isAudioOnly,
      );

      String? downloadedPath;
      await for (final progress in stream) {
        if (task.isCanceled) {
          mobileService.cancelCurrentDownload();
          return false;
        }

        task.updateProgress(
          progress: progress.progress,
          eta: progress.eta,
          speed: progress.speed,
          statusMessage: progress.status,
        );

        if (progress.status == 'Complete') {
          final safeTitle = (progress.currentVideoTitle ?? task.title)
              .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          final ext = task.options.isAudioOnly ? 'mp3' : 'mp4';
          final candidate = File('$downloadDir/$safeTitle.$ext');
          if (await candidate.exists()) {
            downloadedPath = candidate.path;
          } else {
            final dir = Directory(downloadDir);
            if (await dir.exists()) {
              final files = dir.listSync();
              for (final f in files) {
                if (f is File && f.path.contains(safeTitle)) {
                  downloadedPath = f.path;
                  break;
                }
              }
            }
          }
          downloadedPath ??= '$downloadDir/$safeTitle.$ext';
        }
      }

      if (downloadedPath != null) {
        task.markCompleted(downloadedPath);
        if (!kIsWeb && Platform.isAndroid) {
          await NativeYtDlpBridge.scanFile(downloadedPath);
        }
        await PersistenceManager.addHistoryItem(
          HistoryItem(
            id: task.id,
            title: task.title,
            uploader: task.uploader,
            url: task.url,
            thumbnailUrl: task.thumbnailUrl,
            filePath: downloadedPath,
            isAudioOnly: task.options.isAudioOnly,
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Fallback download exception: $e');
      return false;
    }
  }
}
