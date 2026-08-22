import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class LiveBadge extends StatelessWidget {
  final bool compact;
  final bool pulse;

  const LiveBadge({super.key, this.compact = false, this.pulse = true});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.liveGradientStart, AppColors.liveGradientEnd],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
                width: compact ? 5 : 6,
                height: compact ? 5 : 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: pulse ? (c) => c.repeat(reverse: true) : null)
              .fade(begin: 1, end: 0.25, duration: 600.ms),
          SizedBox(width: compact ? 3 : 4),
          Text('LIVE', style: AppTextStyles.liveBadge),
        ],
      ),
    );

    if (!pulse) return badge;
    return badge
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.04, 1.04),
          duration: 900.ms,
          curve: Curves.easeInOut,
        );
  }
}
