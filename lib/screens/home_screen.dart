import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../engine/argument_builder.dart';
import '../engine/download_engine.dart';
import '../engine/download_task.dart';
import '../models/download_models.dart';
import '../services/app_updater_service.dart';
import '../services/apple_music_service.dart';
import '../services/clipboard_service.dart';
import '../services/media_resolver_service.dart';
import '../services/spotify_metadata_service.dart';
import '../ui/components/apple_sheet.dart';
import '../ui/components/clipboard_pill.dart';
import '../ui/components/frosted_container.dart';
import '../ui/components/media_card.dart';
import '../ui/components/segmented_pill.dart';
import '../ui/theme/apple_theme.dart';
import '../widgets/apple_download_sheet.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

enum AppDownloadMode {
  videos,
  music,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();

  AppDownloadMode _downloadMode = AppDownloadMode.videos;
  String? _detectedClipboardUrl;
  bool _isResolving = false;
  String _resolutionStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _checkClipboard();

    // Check for app updates in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppUpdaterService>().checkForUpdates(notify: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    final url = await ClipboardDetector.checkClipboard();
    if (url != null && mounted) {
      setState(() => _detectedClipboardUrl = url);
    }
  }

  Future<void> _pasteFromClipboard() async {
    await HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _urlController.text = text;
        _detectedClipboardUrl = null;
      });
      await _resolveAndShowSheet(text);
    }
  }

  Future<void> _resolveAndShowSheet(String url) async {
    if (url.isEmpty) return;

    await HapticFeedback.lightImpact();
    setState(() {
      _isResolving = true;
      _resolutionStatus = _downloadMode == AppDownloadMode.music
          ? 'Fetching music & metadata...'
          : 'Resolving media metadata...';
    });

    VideoInfo? videoInfo;
    PlaylistInfo? playlistInfo;

    try {
      final res = await MediaResolverService.resolve(url);
      videoInfo = res.videoInfo;
      playlistInfo = res.playlistInfo;
    } catch (e) {
      debugPrint('Metadata resolution fallback: $e');
      videoInfo = VideoInfo(
        id: url.hashCode.toString(),
        title: url,
        thumbnail: '',
        duration: '',
        uploader: 'Media Stream',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _resolutionStatus = '';
        });
      }
    }

    if (!mounted) return;

    final isPureAudioService =
        SpotifyMetadataService.isSpotifyUrl(url) ||
        AppleMusicService.isAppleMusicUrl(url);

    // If Music / MP3 toggle is active OR the source is Spotify / Apple Music:
    // Download immediately as MP3 with thumbnail and metadata
    if (_downloadMode == AppDownloadMode.music || isPureAudioService) {
      const mp3Options = DownloadOptions(
        isAudioOnly: true,
        audioFormat: 'mp3',
        embedMetadata: true,
        embedThumbnail: true,
        cropArtwork: true,
      );

      if (playlistInfo != null && playlistInfo.entries.isNotEmpty) {
        for (final entry in playlistInfo.entries) {
          _enqueueDownload(
            url: entry.id.isNotEmpty ? entry.id : url,
            title: entry.title,
            uploader: entry.uploader,
            thumbnailUrl: entry.thumbnail,
            duration: entry.duration,
            options: mp3Options,
          );
        }
      } else {
        _enqueueDownload(
          url: url,
          title: videoInfo?.title ?? playlistInfo?.title ?? url,
          uploader: videoInfo?.uploader ?? playlistInfo?.uploader ?? '',
          thumbnailUrl: videoInfo?.thumbnail ?? playlistInfo?.thumbnail ?? '',
          duration: videoInfo?.duration ?? '',
          options: mp3Options,
        );
      }

      _urlController.clear();
      ClipboardDetector.markAsHandled(url);
      return;
    }

    // Otherwise, for Videos mode, present Apple modal sheet for options / quality selection
    final options = await showAppleModalSheet<DownloadOptions>(
      context: context,
      builder: (ctx) => AppleDownloadSheet(
        url: url,
        videoInfo: videoInfo,
        playlistInfo: playlistInfo,
      ),
    );

    if (options != null && mounted) {
      _enqueueDownload(
        url: url,
        title: videoInfo?.title ?? playlistInfo?.title ?? url,
        uploader: videoInfo?.uploader ?? playlistInfo?.uploader ?? '',
        thumbnailUrl: videoInfo?.thumbnail ?? playlistInfo?.thumbnail ?? '',
        duration: videoInfo?.duration ?? '',
        options: options,
      );
      _urlController.clear();
      ClipboardDetector.markAsHandled(url);
    }
  }

  void _enqueueDownload({
    required String url,
    required String title,
    required String uploader,
    required String thumbnailUrl,
    required String duration,
    required DownloadOptions options,
  }) {
    HapticFeedback.mediumImpact();
    final engine = Provider.of<DownloadEngine>(context, listen: false);

    final task = DownloadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}',
      url: url,
      title: title,
      uploader: uploader,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      options: options,
    );

    engine.enqueue(task);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          options.isAudioOnly
              ? 'Added MP3 download: $title'
              : 'Added to queue: $title',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = Provider.of<DownloadEngine>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Floating Top Header with App Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Synco',
                    style: AppleTheme.title1(
                      color: isDark ? Colors.white : Colors.black,
                    ).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.history_rounded),
                    tooltip: 'Library & History',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Top Mode Switcher: Videos (default, left) | Music / MP3 (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: AppleSegmentedPill<AppDownloadMode>(
                values: const [AppDownloadMode.videos, AppDownloadMode.music],
                labels: const ['Videos', 'Music / MP3'],
                icons: const [Icons.videocam_rounded, Icons.music_note_rounded],
                selectedValue: _downloadMode,
                onValueChanged: (mode) {
                  setState(() => _downloadMode = mode);
                },
              ),
            ),

            // In-App Seamless Update Banner
            Consumer<AppUpdaterService>(
              builder: (context, updater, _) {
                final info = updater.latestRelease;
                if (info == null || !info.hasUpdate) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: FrostedContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(12),
                    customBackgroundColor:
                        AppleTheme.systemGreen.withValues(alpha: 0.12),
                    customBorder: Border.all(
                      color: AppleTheme.systemGreen.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppleTheme.systemGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.system_update_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Update Available: v${info.latestVersion}',
                                    style: AppleTheme.headline(
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    updater.isDownloading
                                        ? 'Downloading: ${(updater.downloadProgress * 100).toInt()}%'
                                        : 'Update directly without uninstalling',
                                    style: AppleTheme.caption(
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!updater.isDownloading)
                              ElevatedButton(
                                onPressed: () async {
                                  await HapticFeedback.mediumImpact();
                                  final success =
                                      await updater.downloadAndInstallUpdate();
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to launch update installer'),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppleTheme.systemGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Update',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              )
                            else
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppleTheme.systemGreen,
                                ),
                              ),
                          ],
                        ),
                        if (updater.isDownloading) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: updater.downloadProgress,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppleTheme.systemGreen,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            // Instant Clipboard URL detection banner
            if (_detectedClipboardUrl != null)
              ClipboardPill(
                url: _detectedClipboardUrl!,
                onQuickDownload: () {
                  final url = _detectedClipboardUrl!;
                  setState(() => _detectedClipboardUrl = null);
                  _resolveAndShowSheet(url);
                },
                onDismiss: () {
                  if (_detectedClipboardUrl != null) {
                    ClipboardDetector.markAsHandled(_detectedClipboardUrl!);
                  }
                  setState(() => _detectedClipboardUrl = null);
                },
              ),

            // URL Search / Input capsule
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FrostedContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _downloadMode == AppDownloadMode.music
                          ? Icons.music_note_rounded
                          : Icons.link_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        onSubmitted: (val) => _resolveAndShowSheet(val.trim()),
                        style: AppleTheme.body(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: _downloadMode == AppDownloadMode.music
                              ? 'Paste Spotify, Apple Music, SoundCloud link...'
                              : 'Paste video, movie or playlist link...',
                          hintStyle: AppleTheme.body(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _urlController.clear()),
                      ),
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      tooltip: 'Paste from clipboard',
                      onPressed: _pasteFromClipboard,
                    ),
                    GestureDetector(
                      onTap: _isResolving
                          ? null
                          : () => _resolveAndShowSheet(_urlController.text.trim()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _isResolving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _downloadMode == AppDownloadMode.music
                                    ? Icons.download_rounded
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isResolving)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _resolutionStatus,
                  style: AppleTheme.caption(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

            // Active Tasks & Queue Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  Text(
                    'DOWNLOAD QUEUE',
                    style: AppleTheme.caption(color: Colors.grey).copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (engine.tasks.isNotEmpty)
                    Text(
                      '${engine.tasks.length} total',
                      style: AppleTheme.caption(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                ],
              ),
            ),

            // Tasks List
            Expanded(
              child: engine.tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _downloadMode == AppDownloadMode.music
                                ? Icons.music_note_rounded
                                : Icons.downloading_rounded,
                            size: 56,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _downloadMode == AppDownloadMode.music
                                ? 'No Music Downloads'
                                : 'No Active Downloads',
                            style: AppleTheme.headline(
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _downloadMode == AppDownloadMode.music
                                ? 'Paste any song, album, or playlist link to download MP3'
                                : 'Paste a video or playlist link above to start',
                            style: AppleTheme.caption(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: engine.tasks.length,
                      itemBuilder: (context, index) {
                        final task = engine.tasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ActiveTaskCard(
                            task: task,
                            onCancel: () => engine.cancelTask(task.id),
                            onRestart: () => engine.restartTask(task.id),
                            onRemove: () => engine.removeTask(task.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
