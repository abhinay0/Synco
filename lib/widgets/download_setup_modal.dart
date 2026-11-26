import 'package:flutter/material.dart';
import 'package:synco/models/download_models.dart';

class DownloadSetupModal extends StatefulWidget {
  final VideoInfo? videoInfo;
  final PlaylistInfo? playlistInfo;
  final bool initialAudioOnly;
  final String defaultVideoQuality;
  final String defaultAudioFormat;
  final String defaultAudioBitrate;
  final bool defaultEmbedMetadata;

  const DownloadSetupModal({
    super.key,
    this.videoInfo,
    this.playlistInfo,
    this.initialAudioOnly = false,
    this.defaultVideoQuality = '1080p',
    this.defaultAudioFormat = 'mp3',
    this.defaultAudioBitrate = '320',
    this.defaultEmbedMetadata = true,
  }) : assert(videoInfo != null || playlistInfo != null);

  static Future<DownloadConfiguration?> show(
    BuildContext context, {
    VideoInfo? videoInfo,
    PlaylistInfo? playlistInfo,
    bool initialAudioOnly = false,
    String defaultVideoQuality = '1080p',
    String defaultAudioFormat = 'mp3',
    String defaultAudioBitrate = '320',
    bool defaultEmbedMetadata = true,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    final modal = DownloadSetupModal(
      videoInfo: videoInfo,
      playlistInfo: playlistInfo,
      initialAudioOnly: initialAudioOnly,
      defaultVideoQuality: defaultVideoQuality,
      defaultAudioFormat: defaultAudioFormat,
      defaultAudioBitrate: defaultAudioBitrate,
      defaultEmbedMetadata: defaultEmbedMetadata,
    );

    if (isWide) {
      return showDialog<DownloadConfiguration>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
            child: modal,
          ),
        ),
      );
    }

    return showModalBottomSheet<DownloadConfiguration>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      builder: (ctx) => modal,
    );
  }

  @override
  State<DownloadSetupModal> createState() => _DownloadSetupModalState();
}

class _DownloadSetupModalState extends State<DownloadSetupModal> {
  late bool _isAudioOnly;
  late String _selectedQuality;
  late String _audioFormat;
  late String _audioBitrate;
  late bool _embedMetadata;
  bool _downloadSubtitles = false;

  // Playlist / Channel selection state
  final Set<int> _selectedIndices = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _isAudioOnly = widget.initialAudioOnly;
    _audioFormat = widget.defaultAudioFormat;
    _audioBitrate = widget.defaultAudioBitrate;
    _embedMetadata = widget.defaultEmbedMetadata;

    final available = _availableVideoQualities;
    if (available.contains(widget.defaultVideoQuality)) {
      _selectedQuality = widget.defaultVideoQuality;
    } else {
      _selectedQuality = available.first;
    }

    if (widget.playlistInfo != null) {
      _selectedIndices.addAll(
        List<int>.generate(
          widget.playlistInfo!.entries.length,
          (index) => index + 1,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _availableVideoQualities {
    if (widget.videoInfo != null &&
        widget.videoInfo!.availableQualities.isNotEmpty) {
      return ['Best', ...widget.videoInfo!.availableQualities];
    }
    return const ['Best', '2160p', '1440p', '1080p', '720p', '480p', '360p'];
  }

  bool get _isAllSelected =>
      widget.playlistInfo != null &&
      _selectedIndices.length == widget.playlistInfo!.entries.length &&
      widget.playlistInfo!.entries.isNotEmpty;

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectedIndices.clear();
      if (value == true && widget.playlistInfo != null) {
        _selectedIndices.addAll(
          List<int>.generate(
            widget.playlistInfo!.entries.length,
            (index) => index + 1,
          ),
        );
      }
    });
  }

  void _onItemChecked(int oneBasedIndex, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIndices.add(oneBasedIndex);
      } else {
        _selectedIndices.remove(oneBasedIndex);
      }
    });
  }

  void _onDownloadPressed() {
    final sortedSelection = _selectedIndices.toList()..sort();
    Navigator.of(context).pop(
      DownloadConfiguration(
        selectedIndices:
            widget.playlistInfo != null ? sortedSelection : null,
        qualityId: _isAudioOnly ? 'Audio' : _selectedQuality,
        isAudioOnly: _isAudioOnly,
        audioFormat: _audioFormat,
        audioBitrate: _audioBitrate,
        embedMetadata: _embedMetadata,
        downloadSubtitles: _downloadSubtitles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCollection = widget.playlistInfo != null;
    final isChannel = widget.playlistInfo?.isChannel == true;
    final title =
        widget.videoInfo?.title ?? widget.playlistInfo?.title ?? 'Media';
    final uploader =
        widget.videoInfo?.uploader ?? widget.playlistInfo?.uploader ?? '';
    final thumbnail =
        widget.videoInfo?.thumbnail ?? widget.playlistInfo?.thumbnail ?? '';
    final duration = widget.videoInfo?.duration ?? '';

    final filteredEntries = <({int oneBasedIndex, VideoInfo entry})>[];
    if (widget.playlistInfo != null) {
      for (int i = 0; i < widget.playlistInfo!.entries.length; i++) {
        final entry = widget.playlistInfo!.entries[i];
        if (_searchQuery.isEmpty ||
            entry.title.toLowerCase().contains(_searchQuery)) {
          filteredEntries.add((oneBasedIndex: i + 1, entry: entry));
        }
      }
    }

    final canStart = !isCollection || _selectedIndices.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  isChannel
                      ? 'Download Channel'
                      : (isCollection ? 'Download Playlist' : 'Configure Download'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Media Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 96,
                    height: 56,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    child: thumbnail.isNotEmpty
                        ? Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.movie_outlined),
                          )
                        : Icon(
                            isChannel
                                ? Icons.subscriptions_rounded
                                : Icons.play_circle_outline_rounded,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (uploader.isNotEmpty) uploader,
                          if (isCollection)
                            '${widget.playlistInfo!.entries.length} videos'
                          else if (duration.isNotEmpty && duration != '0:00')
                            duration,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Video vs Audio Mode Toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.videocam_rounded, size: 18),
                label: Text('Video (MP4)'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.music_note_rounded, size: 18),
                label: Text('Audio / Music'),
              ),
            ],
            selected: {_isAudioOnly},
            onSelectionChanged: (selection) {
              setState(() => _isAudioOnly = selection.first);
            },
          ),
          const SizedBox(height: 14),

          // Quality / Audio Format Pickers
          if (!_isAudioOnly)
            DropdownButtonFormField<String>(
              initialValue: _selectedQuality,
              decoration: const InputDecoration(
                labelText: 'Video Quality',
                prefixIcon: Icon(Icons.hd_outlined),
              ),
              items: _availableVideoQualities
                  .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedQuality = val);
              },
            )
          else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _audioFormat,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      prefixIcon: Icon(Icons.audiotrack_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'mp3', child: Text('MP3')),
                      DropdownMenuItem(value: 'm4a', child: Text('M4A')),
                      DropdownMenuItem(value: 'opus', child: Text('OPUS')),
                      DropdownMenuItem(value: 'wav', child: Text('WAV')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _audioFormat = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _audioBitrate,
                    decoration: const InputDecoration(
                      labelText: 'Bitrate',
                      prefixIcon: Icon(Icons.graphic_eq_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: '320', child: Text('320 kbps')),
                      DropdownMenuItem(value: '192', child: Text('192 kbps')),
                      DropdownMenuItem(value: '128', child: Text('128 kbps')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _audioBitrate = val);
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 10),

          // Options Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('Embed Metadata & Art'),
                selected: _embedMetadata,
                onSelected: (v) => setState(() => _embedMetadata = v),
              ),
              if (!_isAudioOnly)
                FilterChip(
                  label: const Text('Embed Subtitles'),
                  selected: _downloadSubtitles,
                  onSelected: (v) => setState(() => _downloadSubtitles = v),
                ),
            ],
          ),

          // Playlist / Channel Item Selector
          if (isCollection) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter items in ${isChannel ? "channel" : "playlist"}...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(value: _isAllSelected, onChanged: _toggleSelectAll),
                const Text('Select All'),
                const Spacer(),
                Text(
                  '${_selectedIndices.length} of ${widget.playlistInfo!.entries.length} selected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredEntries.length,
                  itemBuilder: (context, index) {
                    final item = filteredEntries[index];
                    return CheckboxListTile(
                      value: _selectedIndices.contains(item.oneBasedIndex),
                      onChanged: (val) =>
                          _onItemChecked(item.oneBasedIndex, val),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.entry.duration.isNotEmpty
                          ? Text(
                              item.entry.duration,
                              style: theme.textTheme.bodySmall,
                            )
                          : null,
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 48,
                          height: 30,
                          child: item.entry.thumbnail.isNotEmpty
                              ? Image.network(
                                  item.entry.thumbnail,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Center(
                                    child: Text('${item.oneBasedIndex}'),
                                  ),
                                )
                              : Center(child: Text('${item.oneBasedIndex}')),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: canStart ? _onDownloadPressed : null,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  isCollection
                      ? 'Download (${_selectedIndices.length})'
                      : 'Start Download',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
