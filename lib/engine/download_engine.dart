import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

    // Build arguments mirroring Seal's dynamic builder
    final args = DynamicArgumentBuilder.buildDownloadArguments(
      task.url,
      downloadDir,
      task.options,
    );

    try {
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

      String? lastOutputFilename;

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
    // Default to Downloads on desktop, or platform storage
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      final downloads = '$home/Downloads';
      if (await Directory(downloads).exists()) return downloads;
    }
    return Directory.current.path;
  }
}
