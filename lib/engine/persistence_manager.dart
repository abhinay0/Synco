import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_task.dart';

class HistoryItem {
  final String id;
  final String title;
  final String uploader;
  final String url;
  final String thumbnailUrl;
  final String filePath;
  final bool isAudioOnly;
  final DateTime downloadedAt;
  final int fileSizeBytes;

  HistoryItem({
    required this.id,
    required this.title,
    required this.uploader,
    required this.url,
    required this.thumbnailUrl,
    required this.filePath,
    required this.isAudioOnly,
    DateTime? downloadedAt,
    this.fileSizeBytes = 0,
  }) : downloadedAt = downloadedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'uploader': uploader,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'filePath': filePath,
        'isAudioOnly': isAudioOnly,
        'downloadedAt': downloadedAt.toIso8601String(),
        'fileSizeBytes': fileSizeBytes,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        uploader: json['uploader'] as String? ?? 'Unknown',
        url: json['url'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        filePath: json['filePath'] as String? ?? '',
        isAudioOnly: json['isAudioOnly'] as bool? ?? false,
        downloadedAt: json['downloadedAt'] != null
            ? DateTime.tryParse(json['downloadedAt'])
            : null,
        fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      );
}

class PersistenceManager {
  static const String _queueBackupKey = 'synco_task_queue_backup_v2';
  static const String _historyKey = 'synco_download_history_v2';

  /// Save active task queue backup mirroring Seal's PreferenceUtil.encodeTaskListBackup
  static Future<void> saveQueueBackup(List<DownloadTask> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Filter out tasks that are already completed to avoid duplicates
      final activeTasks = tasks.where((t) => !t.isDone).map((t) => t.toJson()).toList();
      await prefs.setString(_queueBackupKey, jsonEncode(activeTasks));
    } catch (e) {
      debugPrint('PersistenceManager: Failed to backup queue: $e');
    }
  }

  /// Restore tasks from backup on startup mirroring Seal's enqueueFromBackup
  static Future<List<DownloadTask>> restoreQueueBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_queueBackupKey);
      if (dataStr == null || dataStr.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(dataStr);
      return jsonList
          .map((item) => DownloadTask.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PersistenceManager: Failed to restore queue: $e');
      return [];
    }
  }

  /// Save completed item into history mirroring Seal's DatabaseUtil.insertInfo
  static Future<void> addHistoryItem(HistoryItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();
      // Prepend to show latest first
      history.insert(0, item);

      // Keep up to 200 items in history
      final trimmed = history.take(200).map((h) => h.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(trimmed));
    } catch (e) {
      debugPrint('PersistenceManager: Failed to add history: $e');
    }
  }

  /// Get all history items
  static Future<List<HistoryItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_historyKey);
      if (dataStr == null || dataStr.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(dataStr);
      return jsonList
          .map((item) => HistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PersistenceManager: Failed to get history: $e');
      return [];
    }
  }

  /// Delete a single history item
  static Future<void> deleteHistoryItem(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();
      history.removeWhere((item) => item.id == id);
      await prefs.setString(
        _historyKey,
        jsonEncode(history.map((h) => h.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('PersistenceManager: Failed to delete history item: $e');
    }
  }

  /// Clear all history
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
