import 'package:flutter/foundation.dart';
import 'argument_builder.dart';

enum TaskStatus {
  idle,
  fetchingInfo,
  readyWithInfo,
  running,
  completed,
  error,
  canceled,
}

class DownloadTask extends ChangeNotifier {
  final String id;
  final String url;
  String title;
  String uploader;
  String thumbnailUrl;
  String duration;
  final DownloadOptions options;
  final DateTime createdAt;

  TaskStatus _status = TaskStatus.idle;
  double _progress = 0.0;
  String _speed = '';
  String _eta = '';
  String _statusMessage = 'Queued';
  String? _errorMessage;
  String? _downloadedFilePath;

  // Process / Stream cancellation reference
  VoidCallback? onCancel;

  DownloadTask({
    required this.id,
    required this.url,
    this.title = '',
    this.uploader = '',
    this.thumbnailUrl = '',
    this.duration = '',
    required this.options,
    DateTime? createdAt,
    TaskStatus status = TaskStatus.idle,
    double progress = 0.0,
    String? downloadedFilePath,
  })  : createdAt = createdAt ?? DateTime.now(),
        _status = status,
        _progress = progress,
        _downloadedFilePath = downloadedFilePath {
    if (title.isEmpty) title = url;
  }

  // Getters
  TaskStatus get status => _status;
  double get progress => _progress;
  String get speed => _speed;
  String get eta => _eta;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get downloadedFilePath => _downloadedFilePath;

  bool get isRunning =>
      _status == TaskStatus.running || _status == TaskStatus.fetchingInfo;
  bool get isDone => _status == TaskStatus.completed;
  bool get isFailed => _status == TaskStatus.error;
  bool get isCanceled => _status == TaskStatus.canceled;

  void updateInfo({
    required String title,
    required String uploader,
    required String thumbnailUrl,
    required String duration,
  }) {
    this.title = title;
    this.uploader = uploader;
    this.thumbnailUrl = thumbnailUrl;
    this.duration = duration;
    notifyListeners();
  }

  void setStatus(TaskStatus status, {String? message, String? error}) {
    _status = status;
    if (message != null) _statusMessage = message;
    if (error != null) _errorMessage = error;
    notifyListeners();
  }

  void updateProgress({
    required double progress,
    String? speed,
    String? eta,
    String? statusMessage,
  }) {
    _progress = progress.clamp(0.0, 1.0);
    if (speed != null) _speed = speed;
    if (eta != null) _eta = eta;
    if (statusMessage != null) _statusMessage = statusMessage;
    notifyListeners();
  }

  void markCompleted(String filePath) {
    _status = TaskStatus.completed;
    _progress = 1.0;
    _downloadedFilePath = filePath;
    _statusMessage = 'Completed';
    notifyListeners();
  }

  void cancel() {
    if (isRunning) {
      onCancel?.call();
      _status = TaskStatus.canceled;
      _statusMessage = 'Canceled';
      notifyListeners();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'uploader': uploader,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'status': _status.name,
      'progress': _progress,
      'downloadedFilePath': _downloadedFilePath,
      'createdAt': createdAt.toIso8601String(),
      'isAudioOnly': options.isAudioOnly,
      'audioFormat': options.audioFormat,
      'resolution': options.resolution,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'idle';
    final taskStatus = TaskStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => TaskStatus.idle,
    );

    // If an unfinished task is recovered, mark it as canceled so it can be resumed
    final effectiveStatus = (taskStatus == TaskStatus.running ||
            taskStatus == TaskStatus.fetchingInfo)
        ? TaskStatus.canceled
        : taskStatus;

    final isAudioOnly = json['isAudioOnly'] as bool? ?? false;
    final audioFormat = json['audioFormat'] as String? ?? 'mp3';
    final resolution = json['resolution'] as String? ?? '1080';

    return DownloadTask(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String? ?? '',
      uploader: json['uploader'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      status: effectiveStatus,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      downloadedFilePath: json['downloadedFilePath'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      options: DownloadOptions(
        isAudioOnly: isAudioOnly,
        audioFormat: audioFormat,
        resolution: resolution,
      ),
    );
  }
}
