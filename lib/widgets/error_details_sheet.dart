import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:synco/models/download_models.dart';

class ErrorDetailsSheet extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  const ErrorDetailsSheet({
    super.key,
    required this.task,
    this.onRetry,
    this.onOpenSettings,
  });

  static Future<void> show(
    BuildContext context, {
    required DownloadTask task,
    VoidCallback? onRetry,
    VoidCallback? onOpenSettings,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
            child: ErrorDetailsSheet(
              task: task,
              onRetry: onRetry,
              onOpenSettings: onOpenSettings,
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
        ),
        child: ErrorDetailsSheet(
          task: task,
          onRetry: onRetry,
          onOpenSettings: onOpenSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final logText = task.errorDetails ?? task.errorSummary ?? 'No details';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Failed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Concise Diagnosis Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              task.errorSummary ?? 'The download encountered an error.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFFFF8A8A) : Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Recommended Fix Box
          if (task.errorFixHint != null && task.errorFixHint!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to fix',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.errorFixHint!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TECHNICAL LOG',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: logText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error log copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copy Log'),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Flexible(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0B0F)
                    : const Color(0xFFF1F3F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  logText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (task.isEngineFixable && onOpenSettings != null) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenSettings!();
                  },
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Engine Settings'),
                ),
                const SizedBox(width: 10),
              ],
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRetry!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry Download'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
