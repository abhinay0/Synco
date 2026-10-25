import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/apple_theme.dart';
import 'frosted_container.dart';

class ClipboardPill extends StatelessWidget {
  final String url;
  final VoidCallback onQuickDownload;
  final VoidCallback onDismiss;

  const ClipboardPill({
    super.key,
    required this.url,
    required this.onQuickDownload,
    required this.onDismiss,
  });

  IconData _getDomainIcon(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return Icons.play_circle_fill_rounded;
    } else if (url.contains('instagram.com')) {
      return Icons.camera_alt_rounded;
    } else if (url.contains('tiktok.com')) {
      return Icons.music_note_rounded;
    } else if (url.contains('twitter.com') || url.contains('x.com')) {
      return Icons.alternate_email_rounded;
    } else if (url.contains('soundcloud.com')) {
      return Icons.graphic_eq_rounded;
    }
    return Icons.link_rounded;
  }

  String _getDomainLabel(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'YouTube';
    if (url.contains('instagram.com')) return 'Instagram';
    if (url.contains('tiktok.com')) return 'TikTok';
    if (url.contains('twitter.com') || url.contains('x.com')) return 'X / Twitter';
    if (url.contains('soundcloud.com')) return 'SoundCloud';
    return 'Media Link';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FrostedContainer(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        blurSigma: 24,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getDomainIcon(url),
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Link in Clipboard (${_getDomainLabel(url)})',
                    style: AppleTheme.caption(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppleTheme.subheadline(
                      color: isDark ? Colors.white : Colors.black,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onQuickDownload();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Download',
                  style: AppleTheme.subheadline(color: Colors.white).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                onDismiss();
              },
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}
