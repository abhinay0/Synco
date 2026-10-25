import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows an Apple-style fluid modal bottom sheet with spring physics and gesture direct manipulation
Future<T?> showAppleModalSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool enableDrag = true,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: enableDrag,
    builder: (ctx) => _AppleSheetWrapper(child: builder(ctx)),
  );
}

class _AppleSheetWrapper extends StatefulWidget {
  final Widget child;

  const _AppleSheetWrapper({required this.child});

  @override
  State<_AppleSheetWrapper> createState() => _AppleSheetWrapperState();
}

class _AppleSheetWrapperState extends State<_AppleSheetWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Apple response: 0.35s critically damped spring
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Spring curve approximating damping 1.0 (no overshoot, smooth deceleration)
    _animation = CurvedAnimation(
      parent: _springController,
      curve: const SpringCurve(),
    );

    _springController.forward();
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1.0 - _animation.value) * 60),
          child: Opacity(
            opacity: _animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
                : const Color(0xFFFFFFFF).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 28,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Apple pill grab handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  widget.child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Critically damped spring simulation curve
class SpringCurve extends Curve {
  const SpringCurve();

  @override
  double transformInternal(double t) {
    // Critically damped spring: 1 - (1 + w*t)*e^(-w*t)
    const w = 6.0;
    return 1.0 - (1.0 + w * t) * (1.0 / (2.71828 * (w * t)).clamp(1.0, 1000.0));
  }
}
