import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import '../engine/persistence_manager.dart';
import '../ui/components/frosted_container.dart';
import '../ui/theme/apple_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _history = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _filterType = 0; // 0 = All, 1 = Videos, 2 = Audio

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await PersistenceManager.getHistory();
    setState(() {
      _history = items;
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(String id) async {
    await HapticFeedback.lightImpact();
    await PersistenceManager.deleteHistoryItem(id);
    await _loadHistory();
  }

  Future<void> _clearAll() async {
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Download History'),
        content: const Text(
          'This will remove all download records from the history list. Downloaded files on disk will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppleTheme.systemPink),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PersistenceManager.clearHistory();
      await _loadHistory();
    }
  }

  void _openFile(String path) {
    HapticFeedback.selectionClick();
    if (path.isNotEmpty && File(path).existsSync()) {
      OpenFile.open(path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File not found at: $path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<HistoryItem> get _filteredHistory {
    return _history.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.uploader.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesType = _filterType == 0 ||
          (_filterType == 1 && !item.isAudioOnly) ||
          (_filterType == 2 && item.isAudioOnly);

      return matchesSearch && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Library & History',
          style: AppleTheme.title2(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearAll,
              tooltip: 'Clear History',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FrostedContainer(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  icon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                  hintText: 'Search downloaded media...',
                  hintStyle: AppleTheme.subheadline(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(0, 'All (${_history.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  1,
                  'Videos (${_history.where((h) => !h.isAudioOnly).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  2,
                  'Audio (${_history.where((h) => h.isAudioOnly).length})',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _filteredHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _searchQuery.isNotEmpty
                                ? Icon(
                                    Icons.search_off_rounded,
                                    size: 54,
                                    color:
                                        isDark ? Colors.white30 : Colors.black26,
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Opacity(
                                      opacity: 0.35,
                                      child: Image.asset(
                                        'assets/icon/app_icon.png',
                                        width: 58,
                                        height: 58,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No downloads match "$_searchQuery"'
                                  : 'No downloaded media yet',
                              style: AppleTheme.subheadline(
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final item = _filteredHistory[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            child: FrostedContainer(
                              borderRadius: 16,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      color: isDark
                                          ? const Color(0xFF2C2C2E)
                                          : const Color(0xFFE5E5EA),
                                      child: item.thumbnailUrl.isNotEmpty
                                          ? Image.network(
                                              item.thumbnailUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  Icon(
                                                item.isAudioOnly
                                                    ? Icons.audiotrack_rounded
                                                    : Icons.videocam_rounded,
                                              ),
                                            )
                                          : Icon(
                                              item.isAudioOnly
                                                  ? Icons.audiotrack_rounded
                                                  : Icons.videocam_rounded,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppleTheme.headline(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.uploader,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppleTheme.caption(
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.downloadedAt.month}/${item.downloadedAt.day}/${item.downloadedAt.year}',
                                          style: AppleTheme.caption(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 30,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: () => _openFile(item.filePath),
                                    tooltip: 'Open Media',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                    onPressed: () => _deleteItem(item.id),
                                    tooltip: 'Delete Record',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int type, String label) {
    final isSelected = _filterType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppleTheme.caption(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
          ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
        ),
      ),
    );
  }
}
