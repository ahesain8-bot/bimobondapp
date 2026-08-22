import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';

/// Smoothly animates numeric changes (viewer / like counters).
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final bool compact;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 350),
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        final display = compact
            ? animated.round().formatNumber
            : animated.round().toString();
        return Text(display, style: style ?? AppTextStyles.viewerCount);
      },
    );
  }
}
