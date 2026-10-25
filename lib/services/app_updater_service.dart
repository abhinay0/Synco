import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:synco/services/native_ytdlp_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateReleaseInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseTitle;
  final String releaseNotes;
  final String? downloadUrl;
  final int assetSize;

  UpdateReleaseInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseTitle,
    required this.releaseNotes,
    this.downloadUrl,
    this.assetSize = 0,
  });
}

class AppUpdaterService with ChangeNotifier {
  static const String currentAppVersion = '2.0.1';
  static const String githubRepo = 'abhinay0/Synco';

  UpdateReleaseInfo? _latestRelease;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _statusMessage;

  UpdateReleaseInfo? get latestRelease => _latestRelease;
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get statusMessage => _statusMessage;

  /// Check GitHub releases for updates
  Future<UpdateReleaseInfo?> checkForUpdates({bool notify = true}) async {
    if (_isChecking) return _latestRelease;
    _isChecking = true;
    _statusMessage = 'Checking for updates...';
    if (notify) notifyListeners();

    try {
      final url =
          Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Synco-App-Updater',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? '';
        final cleanTag = tagName.replaceAll(RegExp(r'^[vV]'), '').trim();

        final hasUpdate = _isNewerVersion(cleanTag, currentAppVersion);

        // Find relevant platform asset
        String? downloadUrl;
        int assetSize = 0;
        final assets = (data['assets'] as List?) ?? [];

        for (final asset in assets) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (!kIsWeb && Platform.isAndroid && name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            assetSize = asset['size'] as int? ?? 0;
            break;
          } else if (!kIsWeb && Platform.isMacOS && name.endsWith('.dmg')) {
            downloadUrl = asset['browser_download_url'] as String?;
            assetSize = asset['size'] as int? ?? 0;
            break;
          } else if (!kIsWeb && Platform.isWindows && name.endsWith('.zip')) {
            downloadUrl = asset['browser_download_url'] as String?;
            assetSize = asset['size'] as int? ?? 0;
            break;
          }
        }

        // Fallback to html_url or first asset if no exact platform asset
        downloadUrl ??= data['html_url'] as String?;

        _latestRelease = UpdateReleaseInfo(
          currentVersion: currentAppVersion,
          latestVersion: cleanTag.isNotEmpty ? cleanTag : currentAppVersion,
          hasUpdate: hasUpdate,
          releaseTitle: data['name'] as String? ?? 'Release $tagName',
          releaseNotes: data['body'] as String? ?? '',
          downloadUrl: downloadUrl,
          assetSize: assetSize,
        );
      }
    } catch (e) {
      debugPrint('AppUpdaterService check error: $e');
    } finally {
      _isChecking = false;
      _statusMessage = null;
      if (notify) notifyListeners();
    }

    return _latestRelease;
  }

  /// Download and install update without uninstalling
  Future<bool> downloadAndInstallUpdate(
      {Function(double progress)? onProgress}) async {
    final info = _latestRelease;
    final urlStr = info?.downloadUrl;
    if (info == null || urlStr == null || urlStr.isEmpty) return false;

    // Desktop: Launch download link in browser
    if (!kIsWeb && !Platform.isAndroid) {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    }

    // Android: Download APK stream to cache and invoke native package installer
    _isDownloading = true;
    _downloadProgress = 0.0;
    _statusMessage = 'Downloading update...';
    notifyListeners();

    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/synco_update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(urlStr));
      request.headers['User-Agent'] = 'Synco-App-Updater';
      final response = await client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength ?? info.assetSize;
        int receivedBytes = 0;

        final sink = apkFile.openWrite();
        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            _downloadProgress =
                (receivedBytes / totalBytes).clamp(0.0, 1.0);
            onProgress?.call(_downloadProgress);
            notifyListeners();
          }
        }).asFuture();

        await sink.flush();
        await sink.close();

        _statusMessage = 'Launching installer...';
        notifyListeners();

        // Trigger native seamless in-place update
        final launched = await NativeYtDlpBridge.installApk(apkFile.path);
        return launched;
      }
    } catch (e) {
      debugPrint('AppUpdaterService download error: $e');
      _statusMessage = 'Download failed: $e';
      notifyListeners();
    } finally {
      _isDownloading = false;
      notifyListeners();
    }

    return false;
  }

  /// Update embedded yt-dlp core directly from upstream
  Future<Map<String, dynamic>?> updateYtDlpCore() async {
    if (!kIsWeb && Platform.isAndroid) {
      return await NativeYtDlpBridge.updateYtDlp();
    }
    return null;
  }

  /// Helper: compare semver versions
  bool _isNewerVersion(String remote, String current) {
    if (remote.isEmpty || current.isEmpty) return false;
    final rParts =
        remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final cParts =
        current.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}
