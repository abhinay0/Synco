import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/providers/app_state_provider.dart';
import 'package:synco/utils/platform_utils.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all, video, audio, collection

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final theme = Theme.of(context);

    final filtered = appState.history.where((item) {
      if (_filter == 'video' &&
          (item.isAudioOnly ||
              item.contentType == MediaContentType.playlist ||
              item.contentType == MediaContentType.channel)) {
        return false;
      }
      if (_filter == 'audio' && !item.isAudioOnly) return false;
      if (_filter == 'collection' &&
          item.contentType != MediaContentType.playlist &&
          item.contentType != MediaContentType.channel) {
        return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return item.title.toLowerCase().contains(q) ||
            item.subtitle.toLowerCase().contains(q) ||
            item.platform.displayName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          if (appState.history.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text(
                      'This removes all entries from your history list. Downloaded files on disk will not be deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  appState.clearHistory();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search downloads...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Videos', 'video'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Music / Audio', 'audio'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Playlists & Channels', 'collection'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 56,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.25,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              appState.history.isEmpty
                                  ? 'No downloads in history yet'
                                  : 'No matching downloads',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            if (appState.incognitoMode) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Incognito mode is enabled in Settings',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildHistoryCard(context, appState, item);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    AppStateProvider appState,
    DownloadTask item,
  ) {
    final theme = Theme.of(context);
    final date = item.completedAt ?? item.createdAt;
    final dateLabel =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 56,
                height: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                child: item.thumbnail.isNotEmpty
                    ? Image.network(
                        item.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Icon(
                          item.isAudioOnly
                              ? Icons.music_note_rounded
                              : Icons.videocam_rounded,
                        ),
                      )
                    : Icon(
                        item.isAudioOnly
                            ? Icons.music_note_rounded
                            : Icons.videocam_rounded,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.qualityLabel} • ${item.platform.displayName} • $dateLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (item.outputPath.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.outputPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.outputPath.isNotEmpty && !PlatformUtils.useBackendAPI)
              IconButton(
                tooltip: 'Open file',
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                onPressed: () => PlatformUtils.openLocalPath(item.outputPath),
              ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'redownload') {
                  appState.enqueueQuickDownload(
                    item.rawInput,
                    modeOverride: item.mode,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added back to queue')),
                    );
                  }
                } else if (action == 'copy') {
                  await Clipboard.setData(
                    ClipboardData(text: item.resolvedUrl),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  }
                } else if (action == 'delete') {
                  appState.removeHistoryItem(item.id);
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'redownload',
                  child: Text('Download again'),
                ),
                PopupMenuItem(value: 'copy', child: Text('Copy URL')),
                PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
