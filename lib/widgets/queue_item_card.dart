import 'package:flutter/material.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/utils/platform_utils.dart';

class QueueItemCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onRemove;
  final VoidCallback onShowErrorDetails;

  const QueueItemCard({
    super.key,
    required this.task,
    required this.onRetry,
    required this.onCancel,
    required this.onRemove,
    required this.onShowErrorDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeColor = _badgeColor(theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail / Fallback Icon
            _buildThumbnail(context, isDark),
            const SizedBox(width: 14),

            // Title, Metadata & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Badge + Source Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.qualityLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (task.contentType == MediaContentType.playlist ||
                          task.contentType == MediaContentType.channel) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.contentType == MediaContentType.channel
                                ? 'CHANNEL'
                                : 'PLAYLIST',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.subtitle.isNotEmpty
                              ? task.subtitle
                              : task.platform.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.58,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Status-specific Footer
                  _buildStatusFooter(context, theme),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Right Action Buttons
            _buildTrailingActions(context, theme),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(ThemeData theme) {
    if (task.isAudioOnly) return const Color(0xFFA855F7); // Purple for MP3/Audio
    if (task.qualityLabel.contains('2160') || task.qualityLabel.contains('4K')) {
      return const Color(0xFF06B6D4); // Cyan for 4K
    }
    return theme.colorScheme.primary; // Blue for 1080P/Video
  }

  Widget _buildThumbnail(BuildContext context, bool isDark) {
    final bgColor = isDark ? const Color(0xFF1D202B) : const Color(0xFFE9EDF5);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 60,
            color: bgColor,
            child: task.thumbnail.isNotEmpty
                ? Image.network(
                    task.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderIcon(context),
                  )
                : _buildPlaceholderIcon(context),
          ),
        ),
        if (task.status == DownloadTaskStatus.completed)
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          )
        else if (task.status == DownloadTaskStatus.failed)
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context) {
    IconData icon = Icons.download_rounded;
    if (task.isAudioOnly) {
      icon = Icons.music_note_rounded;
    } else if (task.contentType == MediaContentType.playlist) {
      icon = Icons.playlist_play_rounded;
    } else if (task.contentType == MediaContentType.channel) {
      icon = Icons.subscriptions_rounded;
    } else {
      icon = Icons.play_arrow_rounded;
    }
    return Center(
      child: Icon(
        icon,
        size: 26,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildStatusFooter(BuildContext context, ThemeData theme) {
    switch (task.status) {
      case DownloadTaskStatus.queued:
      case DownloadTaskStatus.resolving:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(minHeight: 4),
            ),
            const SizedBox(height: 5),
            Text(
              task.statusMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        );

      case DownloadTaskStatus.downloading:
        final pct = (task.progress * 100).clamp(0, 100).toStringAsFixed(0);
        final metrics = [
          '$pct%',
          if (task.speed.isNotEmpty) task.speed,
          if (task.eta.isNotEmpty) 'ETA ${task.eta}',
        ].join(' • ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.currentItemTitle.isNotEmpty
                        ? task.currentItemTitle
                        : task.statusMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  metrics,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        );

      case DownloadTaskStatus.completed:
        return Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Color(0xFF22C55E),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                task.outputPath.isNotEmpty ? task.outputPath : 'Completed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ),
          ],
        );

      case DownloadTaskStatus.cancelled:
        return Text(
          'Cancelled • Tap retry to resume',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        );

      case DownloadTaskStatus.failed:
        // Compact, bounded 2-line error summary + "Details" link — NEVER dumps raw logs!
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.errorSummary ?? 'Download failed.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.35,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: onShowErrorDetails,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.isEngineFixable
                          ? 'View Details & Fix Guide'
                          : 'View Details',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildTrailingActions(BuildContext context, ThemeData theme) {
    if (task.isActive) {
      return IconButton(
        onPressed: onCancel,
        tooltip: 'Cancel download',
        icon: const Icon(Icons.stop_circle_outlined),
        color: Colors.redAccent,
      );
    }

    if (task.status == DownloadTaskStatus.completed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.outputPath.isNotEmpty && !PlatformUtils.useBackendAPI)
            IconButton(
              onPressed: () async {
                final opened = await PlatformUtils.openLocalPath(
                  task.outputPath,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved at: ${task.outputPath}')),
                  );
                }
              },
              tooltip: 'Open file',
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              color: theme.colorScheme.primary,
            ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove from queue',
            icon: const Icon(Icons.close_rounded, size: 20),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ],
      );
    }

    // Failed or Cancelled
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onRetry,
          tooltip: 'Retry download',
          icon: const Icon(Icons.refresh_rounded, size: 21),
          color: theme.colorScheme.primary,
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: 'Remove',
          icon: const Icon(Icons.close_rounded, size: 20),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}
