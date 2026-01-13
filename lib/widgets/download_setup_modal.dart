import 'package:flutter/material.dart';
import 'package:synco/models/download_models.dart';

class DownloadConfiguration {
  final List<int>? selectedIndices; // For playlists
  final String qualityId; // "Best", "1080p", or "Audio"
  final bool isAudioOnly;

  DownloadConfiguration({
    this.selectedIndices,
    required this.qualityId,
    required this.isAudioOnly,
  });
}

class DownloadSetupModal extends StatefulWidget {
  final VideoInfo? videoInfo;
  final PlaylistInfo? playlistInfo;

  const DownloadSetupModal({super.key, this.videoInfo, this.playlistInfo})
    : assert(videoInfo != null || playlistInfo != null);

  @override
  State<DownloadSetupModal> createState() => _DownloadSetupModalState();
}

class _DownloadSetupModalState extends State<DownloadSetupModal> {
  String _selectedQuality = 'Best';
  bool _isAudioOnly = false;

  // Playlist State
  final Set<int> _selectedIndices = {};
  bool _isAllSelected = true;

  @override
  void initState() {
    super.initState();
    if (widget.playlistInfo != null) {
      // Select all by default
      _selectedIndices.addAll(
        List.generate(
          widget.playlistInfo!.entries.length,
          (index) => index + 1,
        ),
      );
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isAllSelected = value ?? false;
      _selectedIndices.clear();
      if (_isAllSelected) {
        _selectedIndices.addAll(
          List.generate(
            widget.playlistInfo!.entries.length,
            (index) => index + 1,
          ),
        );
      }
    });
  }

  void _onItemChecked(int index, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIndices.add(index);
      } else {
        _selectedIndices.remove(index);
      }
      _isAllSelected =
          _selectedIndices.length == widget.playlistInfo!.entries.length;
    });
  }

  List<String> get _availableQualities {
    // Merge qualities from metadata or provide defaults
    // If it's a playlist we might have to stick to generic options
    if (widget.videoInfo != null &&
        widget.videoInfo!.availableQualities.isNotEmpty) {
      return ['Best', ...widget.videoInfo!.availableQualities, 'Audio Only'];
    }
    return ['Best', '1080p', '720p', '480p', 'Audio Only'];
  }

  void _onDownloadPressed() {
    Navigator.of(context).pop(
      DownloadConfiguration(
        selectedIndices: widget.playlistInfo != null
            ? _selectedIndices.toList()
            : null,
        qualityId: _isAudioOnly ? 'Audio' : _selectedQuality,
        isAudioOnly: _isAudioOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        widget.videoInfo?.title ?? widget.playlistInfo?.title ?? 'Unknown';
    final thumbnail = widget.videoInfo?.thumbnail;
    // playlists might not have a main thumbnail easily available in flat-playlist,
    // but usually the first entry has one if we parsed it properly.

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            widget.playlistInfo != null
                ? 'Download Playlist'
                : 'Download Video',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Media Summary
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnail != null && thumbnail.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumbnail,
                    width: 120,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(width: 120, height: 68, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (widget.playlistInfo != null)
                      Text(
                        '${widget.playlistInfo!.entries.length} videos',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quality Selection
          DropdownButtonFormField<String>(
            value: _selectedQuality == 'Audio Only'
                ? 'Audio Only'
                : _selectedQuality, // Simple logic
            decoration: const InputDecoration(
              labelText: 'Quality',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: _availableQualities.map((q) {
              return DropdownMenuItem(value: q, child: Text(q));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  if (value == 'Audio Only') {
                    _isAudioOnly = true;
                    _selectedQuality = 'Audio Only'; // Just for display state
                  } else {
                    _isAudioOnly = false;
                    _selectedQuality = value;
                  }
                });
              }
            },
          ),

          // Playlist Selection Area
          if (widget.playlistInfo != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(value: _isAllSelected, onChanged: _toggleSelectAll),
                const Text('Select All'),
                const Spacer(),
                Text('${_selectedIndices.length} items selected'),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.playlistInfo!.entries.length,
                itemBuilder: (context, index) {
                  // indices in yt-dlp are 1-based usually
                  final entry = widget.playlistInfo!.entries[index];
                  final itemIndex = index + 1;
                  return CheckboxListTile(
                    value: _selectedIndices.contains(itemIndex),
                    onChanged: (val) => _onItemChecked(itemIndex, val),
                    title: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: Text(
                      '$itemIndex',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _onDownloadPressed,
                child: const Text('Start Download'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
