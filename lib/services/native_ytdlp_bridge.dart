import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  NativeExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

class NativeYtDlpBridge {
  static const MethodChannel _channel = MethodChannel('synco/ytdlp');

  static final Map<String, void Function(double progress, int eta, String line)>
      _progressListeners = {};
  static bool _initialized = false;

  /// Initialize native event listener and backend engine
  static void initialize() {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final taskId = args['taskId'] as String?;
        final progress = (args['progress'] as num?)?.toDouble() ?? 0.0;
        final eta = (args['eta'] as num?)?.toInt() ?? 0;
        final line = args['line'] as String? ?? '';

        if (taskId != null && _progressListeners.containsKey(taskId)) {
          _progressListeners[taskId]!(progress, eta, line);
        }
      }
    });

    _channel.invokeMethod('init').catchError((e) {
      debugPrint('NativeYtDlpBridge init error: $e');
    });
  }

  /// Execute download on Android using embedded yt-dlp & FFmpeg
  static Future<NativeExecutionResult> execute({
    required String taskId,
    required String url,
    required List<String> args,
    void Function(double progress, int eta, String line)? onProgress,
  }) async {
    if (onProgress != null) {
      _progressListeners[taskId] = onProgress;
    }

    try {
      final res = await _channel.invokeMethod('execute', {
        'taskId': taskId,
        'url': url,
        'args': args,
      });

      final map = Map<String, dynamic>.from(res as Map);
      return NativeExecutionResult(
        exitCode: map['exitCode'] as int? ?? 0,
        stdout: map['out'] as String? ?? '',
        stderr: map['err'] as String? ?? '',
      );
    } catch (e) {
      return NativeExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: e.toString(),
      );
    } finally {
      _progressListeners.remove(taskId);
    }
  }

  /// Cancel running task by ID
  static Future<void> cancel(String taskId) async {
    try {
      await _channel.invokeMethod('cancel', {'taskId': taskId});
    } catch (_) {}
    _progressListeners.remove(taskId);
  }

  /// Extract media metadata using embedded yt-dlp
  static Future<String?> getInfo(String url) async {
    try {
      final res = await _channel.invokeMethod('getInfo', {'url': url});
      return res as String?;
    } catch (e) {
      debugPrint('NativeYtDlpBridge getInfo error: $e');
      return null;
    }
  }

  /// Query embedded yt-dlp version
  static Future<String?> getYtDlpVersion() async {
    try {
      final res = await _channel.invokeMethod('getYtDlpVersion');
      return res as String?;
    } catch (_) {
      return null;
    }
  }

  /// Dynamically update yt-dlp python core from upstream
  static Future<Map<String, dynamic>?> updateYtDlp() async {
    try {
      final res = await _channel.invokeMethod('updateYtDlp');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (e) {
      debugPrint('NativeYtDlpBridge updateYtDlp error: $e');
      return null;
    }
  }

  /// Get native public download directory
  static Future<String?> getDownloadDirectory() async {
    try {
      final res = await _channel.invokeMethod('getDownloadDirectory');
      return res as String?;
    } catch (_) {
      return null;
    }
  }

  /// Notify MediaStore of downloaded file so gallery/player sees it immediately
  static Future<void> scanFile(String path) async {
    try {
      await _channel.invokeMethod('scanFile', {'path': path});
    } catch (_) {}
  }

  /// Install downloaded APK via Android system package installer (seamless in-place update)
  static Future<bool> installApk(String filePath) async {
    try {
      final res =
          await _channel.invokeMethod('installApk', {'filePath': filePath});
      return res == true;
    } catch (e) {
      debugPrint('NativeYtDlpBridge installApk error: $e');
      return false;
    }
  }
}
