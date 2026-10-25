import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../engine/argument_builder.dart';
import '../engine/download_engine.dart';
import '../engine/download_task.dart';
import '../models/download_models.dart';
import '../services/app_updater_service.dart';
import '../services/clipboard_service.dart';
import '../services/media_resolver_service.dart';
import '../ui/components/apple_sheet.dart';
import '../ui/components/clipboard_pill.dart';
import '../ui/components/frosted_container.dart';
import '../ui/components/media_card.dart';
import '../ui/theme/apple_theme.dart';
import '../widgets/apple_download_sheet.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();

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
      _resolutionStatus = 'Resolving media metadata...';
    });

    VideoInfo? videoInfo;
    PlaylistInfo? playlistInfo;

    try {
      final res = await MediaResolverService.resolve(url);
      videoInfo = res.videoInfo;
      playlistInfo = res.playlistInfo;
    } catch (e) {
      debugPrint('Metadata resolution fallback: $e');
      // Graceful fallback with placeholder info
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

    // Present Apple modal sheet with spring physics
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
        content: Text('Added to queue: $title'),
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
            // Floating Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Synco',
                        style: AppleTheme.title1(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'Media Suite v2',
                        style: AppleTheme.caption(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
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
                      Icons.link_rounded,
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
                          hintText: 'Paste video or playlist link...',
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
                            : const Icon(
                                Icons.arrow_forward_rounded,
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
                  const SizedBox(width: 8),
                  if (engine.tasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${engine.tasks.length}',
                        style: AppleTheme.caption(
                          color: Theme.of(context).colorScheme.primary,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),

            // Active Tasks List or Empty State
            Expanded(
              child: engine.tasks.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cloud_download_rounded,
                                size: 56,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Ready to Download',
                              style: AppleTheme.title2(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Paste any media link above or copy a URL to your clipboard for 1-tap quick download.',
                                textAlign: TextAlign.center,
                                style: AppleTheme.subheadline(
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Supported Platforms Badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildPlatformBadge('YouTube', isDark),
                                _buildPlatformBadge('Instagram', isDark),
                                _buildPlatformBadge('TikTok', isDark),
                                _buildPlatformBadge('X / Twitter', isDark),
                                _buildPlatformBadge('SoundCloud', isDark),
                                _buildPlatformBadge('Vimeo', isDark),
                                _buildPlatformBadge('1,000+ Sites', isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: engine.tasks.length,
                      itemBuilder: (context, index) {
                        final task = engine.tasks[index];
                        return ActiveTaskCard(
                          task: task,
                          onCancel: () => engine.cancelTask(task.id),
                          onRestart: () => engine.restartTask(task.id),
                          onRemove: () => engine.removeTask(task.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppleTheme.caption(
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }
}
