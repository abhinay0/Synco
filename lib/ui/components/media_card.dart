import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../engine/download_task.dart';
import '../theme/apple_theme.dart';
import 'frosted_container.dart';
import 'tactile_progress_ring.dart';

class ActiveTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback onRestart;
  final VoidCallback onRemove;

  const ActiveTaskCard({
    super.key,
    required this.task,
    required this.onCancel,
    required this.onRestart,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: task,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FrostedContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail or media placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    child: task.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            task.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/icon/app_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & status info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppleTheme.headline(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: task.options.isAudioOnly
                                  ? AppleTheme.systemPurple.withValues(alpha: 0.15)
                                  : AppleTheme.systemBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.options.isAudioOnly
                                  ? task.options.audioFormat?.toUpperCase() ?? 'AUDIO'
                                  : '${task.options.resolution ?? "1080"}P',
                              style: AppleTheme.caption(
                                color: task.options.isAudioOnly
                                    ? AppleTheme.systemPurple
                                    : AppleTheme.systemBlue,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (task.uploader.isNotEmpty)
                            Expanded(
                              child: Text(
                                task.uploader,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppleTheme.caption(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.statusMessage,
                        style: AppleTheme.caption(
                          color: task.isFailed
                              ? AppleTheme.systemPink
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                      if (task.speed.isNotEmpty || task.eta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${task.speed}  •  ETA ${task.eta}',
                          style: AppleTheme.caption(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Action / Progress Ring
                if (task.isRunning) ...[
                  TactileProgressRing(
                    progress: task.progress,
                    size: 42,
                    strokeWidth: 3.5,
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined, size: 22),
                    color: AppleTheme.systemPink,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onCancel();
                    },
                    tooltip: 'Cancel',
                  ),
                ] else if (task.isDone) ...[
                  const TactileProgressRing(
                    progress: 1.0,
                    size: 42,
                    strokeWidth: 3.5,
                    isCompleted: true,
                  ),
                ] else if (task.isCanceled || task.isFailed) ...[
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 24),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onRestart();
                    },
                    tooltip: 'Retry',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onRemove();
                    },
                    tooltip: 'Dismiss',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
