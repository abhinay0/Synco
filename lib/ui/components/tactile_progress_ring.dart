import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/apple_theme.dart';

class TactileProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? trackColor;
  final bool isCompleted;
  final String? centerText;

  const TactileProgressRing({
    super.key,
    required this.progress,
    this.size = 48,
    this.strokeWidth = 4.0,
    this.progressColor,
    this.trackColor,
    this.isCompleted = false,
    this.centerText,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = progressColor ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultTrack = trackColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              progressColor: effectiveColor,
              trackColor: defaultTrack,
            ),
          ),
          if (isCompleted)
            Icon(
              Icons.check_rounded,
              size: size * 0.45,
              color: AppleTheme.systemGreen,
            )
          else if (centerText != null)
            Text(
              centerText!,
              style: AppleTheme.caption(
                color: isDark ? Colors.white : Colors.black,
              ).copyWith(fontWeight: FontWeight.w700),
            )
          else
            Text(
              '${(progress * 100).toInt()}%',
              style: AppleTheme.caption(
                color: isDark ? Colors.white : Colors.black,
              ).copyWith(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
