import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/providers/app_state_provider.dart';
import 'package:synco/screens/history_screen.dart';
import 'package:synco/screens/settings_screen.dart';
import 'package:synco/services/url_resolver_service.dart';
import 'package:synco/utils/theme.dart';
import 'package:synco/widgets/download_setup_modal.dart';
import 'package:synco/widgets/error_details_sheet.dart';
import 'package:synco/widgets/queue_item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();

  bool _isFetchingMetadata = false;
  String _queueFilter = 'all'; // all, active, completed, failed

  // Smart Clipboard Suggestion State
  ParsedMediaInput? _clipboardSuggestion;
  String? _dismissedClipboardRaw;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _urlController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkClipboard());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.removeListener(_onTextChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkClipboard());
    }
  }

  Future<void> _checkClipboard() async {
    if (!mounted) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (!appState.autoDetectClipboard) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || text == _dismissedClipboardRaw) {
        return;
      }

      final parsed = UrlResolverService.extractClipboardMediaLink(
        text,
        preferredMode: appState.mediaMode,
      );
      if (parsed != null && mounted) {
        setState(() => _clipboardSuggestion = parsed);
      }
    } catch (_) {
      // Clipboard may be restricted on some web browsers without gesture
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text?.trim() ?? '';
      if (raw.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clipboard is empty')),
          );
        }
        return;
      }

      if (!mounted) return;
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final parsed = UrlResolverService.parseInput(
        raw,
        preferredMode: appState.mediaMode,
      );

      // Keep full raw text only if it has a share-text hint for Amazon/Spotify,
      // otherwise show the crisp extracted URL in the text box.
      setState(() {
        _urlController.text =
            parsed.platform.isDrmMusicService && parsed.searchHint != null
                ? raw
                : (parsed.cleanUrl.isNotEmpty ? parsed.cleanUrl : raw);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read clipboard — paste directly in box'),
          ),
        );
      }
    }
  }

  /// Processes URL / share text: extracts clean URL, opens configuration modal
  /// in Videos mode (or for playlists/channels), or immediately queues Music/MP3.
  Future<void> _handleSubmitInput({
    String? overrideInput,
    bool quickDownload = false,
  }) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final raw = (overrideInput ?? _urlController.text).trim();
    if (raw.isEmpty) return;

    final parsed = UrlResolverService.parseInput(
      raw,
      preferredMode: appState.mediaMode,
    );

    if (!parsed.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a valid video, music, playlist, or channel link'),
        ),
      );
      return;
    }

    // Quick-download mode (Clipboard banner or Music/MP3 direct button)
    if (quickDownload ||
        (appState.mediaMode == AppMediaMode.music && !parsed.isCollection)) {
      appState.enqueueQuickDownload(raw, modeOverride: appState.mediaMode);
      if (overrideInput == null) {
        _urlController.clear();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              parsed.platform.isDrmMusicService
                  ? 'Matching ${parsed.platform.displayName} track to audio queue...'
                  : 'Added to download queue',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Interactive configuration flow (choose quality, format, or playlist/channel items)
    setState(() => _isFetchingMetadata = true);
    try {
      VideoInfo? videoInfo;
      PlaylistInfo? playlistInfo;

      if (parsed.isCollection) {
        playlistInfo = await appState.downloadService.getPlaylistInfo(
          raw,
          parsed: parsed,
        );
      } else {
        videoInfo = await appState.downloadService.getVideoInfo(
          raw,
          parsed: parsed,
        );
      }

      if (!mounted) return;
      setState(() => _isFetchingMetadata = false);

      final config = await DownloadSetupModal.show(
        context,
        videoInfo: videoInfo,
        playlistInfo: playlistInfo,
        initialAudioOnly: appState.mediaMode == AppMediaMode.music,
        defaultVideoQuality: appState.defaultVideoQuality,
        defaultAudioFormat: appState.defaultAudioFormat,
        defaultAudioBitrate: appState.defaultAudioBitrate,
        defaultEmbedMetadata: appState.embedMetadata,
      );

      if (config != null && mounted) {
        appState.enqueueConfiguredDownload(
          rawInput: raw,
          parsed: parsed,
          config: config,
          videoInfo: videoInfo,
          playlistInfo: playlistInfo,
        );
        if (overrideInput == null) {
          _urlController.clear();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingMetadata = false);
      final friendly = UrlResolverService.formatFriendlyError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendly.summary),
          action: SnackBarAction(
            label: 'Queue Anyway',
            onPressed: () {
              appState.enqueueQuickDownload(
                raw,
                modeOverride: appState.mediaMode,
              );
            },
          ),
        ),
      );
    }
  }

  void _openSettings() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    );
  }

  void _openHistory() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWideDesktop = width >= 980;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 18,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.download_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Synco',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Download History',
            onPressed: _openHistory,
            icon: Badge(
              isLabelVisible: appState.history.isNotEmpty,
              label: Text(
                appState.history.length > 99
                    ? '99+'
                    : '${appState.history.length}',
              ),
              child: const Icon(Icons.history_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: isWideDesktop
            ? _buildDesktopLayout(context, appState, isDark)
            : _buildCompactLayout(context, appState, isDark),
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    AppStateProvider appState,
    bool isDark,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              _buildModeSwitcher(context, appState, isDark),
              if (_clipboardSuggestion != null) ...[
                const SizedBox(height: 14),
                _buildClipboardBanner(context, _clipboardSuggestion!, isDark),
              ],
              const SizedBox(height: 14),
              _buildUrlInputBar(context, appState, isDark),
              const SizedBox(height: 20),
              Expanded(child: _buildQueueSection(context, appState, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AppStateProvider appState,
    bool isDark,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Control Panel
              SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildModeSwitcher(context, appState, isDark),
                      if (_clipboardSuggestion != null) ...[
                        const SizedBox(height: 16),
                        _buildClipboardBanner(
                          context,
                          _clipboardSuggestion!,
                          isDark,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildUrlInputBar(context, appState, isDark),
                      const SizedBox(height: 16),
                      _buildSupportedPlatformsCard(context, isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),

              // Right Download Queue Panel
              Expanded(
                child: _buildQueueSection(context, appState, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitcher(
    BuildContext context,
    AppStateProvider appState,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isMusic = appState.mediaMode == AppMediaMode.music;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? SyncoTheme.darkSurface : SyncoTheme.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? SyncoTheme.darkBorder : SyncoTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabButton(
              icon: Icons.videocam_rounded,
              label: 'Videos',
              selected: !isMusic,
              isDark: isDark,
              onTap: () => appState.setMediaMode(AppMediaMode.video),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeTabButton(
              icon: Icons.music_note_rounded,
              label: 'Music / MP3',
              selected: isMusic,
              isDark: isDark,
              accentOverride: theme.colorScheme.primary,
              onTap: () => appState.setMediaMode(AppMediaMode.music),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipboardBanner(
    BuildContext context,
    ParsedMediaInput suggestion,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final subtitleText =
        suggestion.searchHint ?? suggestion.cleanUrl;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                suggestion.platform.isDrmMusicService
                    ? Icons.music_note_rounded
                    : Icons.play_arrow_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Link in Clipboard (${suggestion.platform.displayName})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () {
                final raw = suggestion.rawInput;
                setState(() {
                  _dismissedClipboardRaw = raw;
                  _clipboardSuggestion = null;
                });
                unawaited(
                  _handleSubmitInput(overrideInput: raw, quickDownload: true),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Download'),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _dismissedClipboardRaw = suggestion.rawInput;
                  _clipboardSuggestion = null;
                });
              },
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInputBar(
    BuildContext context,
    AppStateProvider appState,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isMusic = appState.mediaMode == AppMediaMode.music;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? SyncoTheme.darkSurface : SyncoTheme.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? SyncoTheme.darkBorder : SyncoTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Icon(
            isMusic ? Icons.music_note_rounded : Icons.link_rounded,
            color: theme.colorScheme.primary,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _urlController,
              maxLines: 1,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                hintText: isMusic
                    ? 'Paste Spotify, Apple, Amazon Music or search...'
                    : 'Paste video, playlist, or channel URL...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => unawaited(_handleSubmitInput()),
            ),
          ),
          if (_urlController.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              visualDensity: VisualDensity.compact,
              onPressed: () => _urlController.clear(),
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          IconButton(
            tooltip: 'Paste from clipboard',
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 40,
            width: 48,
            child: FilledButton(
              onPressed: _isFetchingMetadata
                  ? null
                  : () => unawaited(_handleSubmitInput()),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isFetchingMetadata
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isMusic
                          ? Icons.download_rounded
                          : Icons.arrow_forward_rounded,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSection(
    BuildContext context,
    AppStateProvider appState,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final allTasks = appState.queue;
    final visibleTasks = allTasks.where((t) {
      switch (_queueFilter) {
        case 'active':
          return t.isActive;
        case 'completed':
          return t.status == DownloadTaskStatus.completed;
        case 'failed':
          return t.status == DownloadTaskStatus.failed ||
              t.status == DownloadTaskStatus.cancelled;
        default:
          return true;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Queue Header Row
        Row(
          children: [
            Text(
              'DOWNLOAD QUEUE',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const Spacer(),
            Text(
              '${allTasks.length} total',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            if (allTasks.isNotEmpty) ...[
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Queue actions',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                onSelected: (action) {
                  if (action == 'retry_failed') {
                    appState.retryAllFailed();
                  } else if (action == 'clear_done') {
                    appState.clearCompletedTasks();
                  } else if (action == 'clear_all') {
                    appState.clearAllTasks();
                  }
                },
                itemBuilder: (ctx) => [
                  if (appState.failedCount > 0)
                    PopupMenuItem(
                      value: 'retry_failed',
                      child: Text('Retry Failed (${appState.failedCount})'),
                    ),
                  if (appState.completedCount > 0)
                    PopupMenuItem(
                      value: 'clear_done',
                      child: Text('Clear Completed (${appState.completedCount})'),
                    ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Text('Clear Entire Queue'),
                  ),
                ],
              ),
            ],
          ],
        ),

        // Quick Filter Chips when queue has items
        if (allTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildQueueFilterChip('All (${allTasks.length})', 'all'),
                const SizedBox(width: 6),
                _buildQueueFilterChip('Active (${appState.activeCount})', 'active'),
                const SizedBox(width: 6),
                _buildQueueFilterChip(
                  'Done (${appState.completedCount})',
                  'completed',
                ),
                const SizedBox(width: 6),
                _buildQueueFilterChip(
                  'Failed (${appState.failedCount})',
                  'failed',
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Queue Items List or Empty State
        Expanded(
          child: visibleTasks.isEmpty
              ? _buildEmptyQueueState(context, isDark, allTasks.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: visibleTasks.length,
                  itemBuilder: (context, index) {
                    final task = visibleTasks[index];
                    return QueueItemCard(
                      key: ValueKey(task.id),
                      task: task,
                      onRetry: () => appState.retryTask(task.id),
                      onCancel: () => appState.cancelTask(task.id),
                      onRemove: () => appState.removeTask(task.id),
                      onShowErrorDetails: () {
                        unawaited(
                          ErrorDetailsSheet.show(
                            context,
                            task: task,
                            onRetry: () => appState.retryTask(task.id),
                            onOpenSettings: _openSettings,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQueueFilterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _queueFilter == value,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _queueFilter = value),
    );
  }

  Widget _buildEmptyQueueState(
    BuildContext context,
    bool isDark,
    bool isFiltered,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_list_off_rounded
                    : Icons.download_for_offline_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isFiltered
                  ? 'No downloads match this filter'
                  : 'Ready to download',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Switch filter tabs to view other downloads.'
                  : 'Paste any video, playlist, channel, or music link above.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 20),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SourceTag(label: 'YouTube & Shorts'),
                  _SourceTag(label: 'Playlists & Channels'),
                  _SourceTag(label: 'Spotify'),
                  _SourceTag(label: 'Apple Music'),
                  _SourceTag(label: 'Amazon Music'),
                  _SourceTag(label: 'SoundCloud'),
                  _SourceTag(label: '1000+ Sites'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedPlatformsCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart Link Detection',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Paste raw share text from Amazon Music, Spotify, Apple Music, YouTube videos, playlists, or entire @channels. Synco automatically extracts clean URLs, matches tracks, and retries YouTube SABR/EJS streams cleanly.',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final Color? accentOverride;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    this.accentOverride,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBg = isDark
        ? const Color(0xFF4B4E56)
        : theme.colorScheme.primary;
    const activeFg = Colors.white;
    final inactiveFg = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Material(
      color: selected ? activeBg : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? activeFg : inactiveFg),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? activeFg : inactiveFg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  final String label;
  const _SourceTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11.5,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
