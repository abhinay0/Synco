import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:synco/main.dart';
import 'package:synco/screens/settings_screen.dart';
import 'package:synco/services/yt_dlp_service.dart';
import 'package:synco/services/download_service.dart';
import 'package:synco/services/mobile_download_service.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/widgets/download_setup_modal.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  late final DownloadService _downloadService;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      // Note: Web might need another service, but reuse mobile for now or handle later
      // For this task (Android), we use MobileDownloadService
      // We need to import 'package:synco/services/mobile_download_service.dart'
      // But I will use dynamic loading or just conditional import if possible,
      // or just ignore unused code warning for Desktop in this file.
      // We need to update imports.
    }
    // Simple Factory Logic
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      _downloadService = YtDlpService();
    } else {
      // Assuming Mobile
      _downloadService = MobileDownloadService();
    }
  }

  // State
  bool _isFetching = false;
  bool _isDownloading = false;

  // Progress
  String _statusMessage = '';
  double _progress = 0.0;
  String _eta = '';
  String _speed = '';
  String _currentVideoTitle = ''; // Current video being downloaded in playlist
  VideoInfo? _currentVideo;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    setState(() {
      _urlController.text = data?.text ?? '';
    });
  }

  void _cancelDownload() {
    _downloadService.cancelCurrentDownload();
    setState(() {
      _isDownloading = false;
      _statusMessage = 'Cancelled';
      _progress = 0.0;
      _currentVideoTitle = '';
    });
  }

  Future<void> _processUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Reset state
    setState(() {
      _isFetching = true;
      _statusMessage = 'Fetching metadata...';
      _currentVideo = null;
    });

    try {
      VideoInfo? videoInfo;
      PlaylistInfo? playlistInfo;

      debugPrint('Synco: Processing URL - $url');

      if (url.contains('list=')) {
        debugPrint('Synco: Detected playlist URL');
        playlistInfo = await _downloadService.getPlaylistInfo(url);
        debugPrint(
          'Synco: Playlist has ${playlistInfo.entries.length} entries',
        );
      } else {
        debugPrint('Synco: Detected single video URL');
        videoInfo = await _downloadService.getVideoInfo(url);
        debugPrint('Synco: Video title: ${videoInfo.title}');
        debugPrint('Synco: Thumbnail: ${videoInfo.thumbnail}');
        // Store videoInfo for later use
        setState(() {
          _currentVideo = videoInfo;
        });
      }

      setState(() {
        _isFetching = false;
        _statusMessage = '';
      });

      if (!mounted) return;

      debugPrint('Synco: About to show modal...');

      // Show Modal
      final config = await showModalBottomSheet<DownloadConfiguration>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        builder: (ctx) => DownloadSetupModal(
          videoInfo: videoInfo,
          playlistInfo: playlistInfo,
        ),
      );

      debugPrint('Synco: Modal returned config: $config');

      if (config != null) {
        await _startDownload(url, config, playlistInfo, videoInfo);
      }
    } catch (e, stackTrace) {
      debugPrint('Synco Error: $e');
      debugPrint('Synco Stack: $stackTrace');
      _showError(e.toString());
      setState(() => _isFetching = false);
    }
  }

  Future<void> _startDownload(
    String url,
    DownloadConfiguration config,
    PlaylistInfo? playlist,
    VideoInfo? video,
  ) async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Initializing download...';
      _progress = 0.0;
      // Show something in current video logic
      if (playlist != null) {
        _currentVideo = VideoInfo(
          id: 'playlist',
          title: playlist.title,
          thumbnail: playlist.thumbnail,
          duration:
              '${config.selectedIndices?.length ?? playlist.entries.length} videos',
          uploader: playlist.uploader,
        );
      } else if (video != null) {
        _currentVideo = video;
      }
    });

    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      // Get platform-appropriate base path
      String base;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // For mobile, use public Downloads folder if no custom path is set
        base = themeProvider.downloadPath ?? '/storage/emulated/0/Download';
      } else {
        // For desktop, use saved preference or default
        base = themeProvider.downloadPath ?? '/Users/abhinayn/Downloads';
      }

      // Smart Folder Logic: Always create Synco folder
      // If Playlist: Synco/PlaylistName
      // If Single: Synco/
      String downloadPath = '$base/Synco';
      if (playlist != null) {
        final safeTitle = playlist.title.replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        );
        downloadPath = '$downloadPath/$safeTitle';
      }

      final dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      Stream<DownloadProgress> stream;
      if (playlist != null) {
        stream = _downloadService.downloadPlaylist(
          url,
          dir.path,
          selectedIndices: config.selectedIndices,
          qualityId: config.qualityId,
          isAudioOnly: config.isAudioOnly,
        );
      } else {
        stream = _downloadService.downloadVideo(
          url,
          dir.path,
          qualityId: config.qualityId,
          isAudioOnly: config.isAudioOnly,
        );
      }

      stream.listen(
        (event) {
          setState(() {
            // Basic progress update
            if (event.progress > 0) _progress = event.progress;
            _statusMessage = event.status;
            _eta = event.eta;
            _speed = event.speed;
            // Track current video in playlist
            if (event.currentVideoTitle.isNotEmpty) {
              _currentVideoTitle = event.currentVideoTitle;
            }
          });
        },
        onError: (e) => _showError(e.toString()),
        onDone: () {
          setState(() {
            _isDownloading = false;
            _statusMessage = 'Completed';
            _progress = 1.0;
          });

          // Save History unless Incognito
          if (!themeProvider.incognitoMode) {
            // TODO: Implement History Persistence
          }
        },
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    setState(() {
      _isDownloading = false;
      _isFetching = false;
      _statusMessage = 'Error';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // History Button
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              // TODO: Show history screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // Centered Logo/Title
              Text(
                'Synco',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontSize: 56,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Active Download Card
              if (_isFetching || _isDownloading || _progress > 0)
                Card(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                            image:
                                _currentVideo?.thumbnail != null &&
                                    _currentVideo!.thumbnail.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                      _currentVideo!.thumbnail,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _isFetching
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : (_currentVideo?.thumbnail == null
                                    ? const Icon(Icons.downloading)
                                    : null),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isFetching
                                    ? 'Fetching metadata...'
                                    : (_currentVideo?.title ?? 'Processing...'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_isFetching)
                                const LinearProgressIndicator()
                              else ...[
                                LinearProgressIndicator(value: _progress),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _statusMessage,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (_eta.isNotEmpty)
                                      Text(
                                        'ETA: $_eta • $_speed',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                // Show current video title for playlist downloads
                                if (_currentVideoTitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentVideoTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        // Cancel button
                        if (_isDownloading)
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancel Download',
                            onPressed: _cancelDownload,
                          ),
                      ],
                    ),
                  ),
                ),

              // URL Input Section
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'Paste link here...',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      onSubmitted: (_) => _processUrl(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Paste Button - Matches Download Color
                  IconButton.filled(
                    // Changed to filled to match primary color
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded),
                    tooltip: 'Paste from clipboard',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Download / Fetch Button
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: (_isFetching || _isDownloading)
                      ? null
                      : _processUrl,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_isFetching ? 'Please wait...' : 'Download'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.primary, // Explicitly primary
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Footer
              Text(
                'Synco v1.0.0-alpha',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
