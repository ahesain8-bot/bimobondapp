import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';

/// Circular share control with a centered label underneath.
class LiveRoomShareOption extends StatelessWidget {
  const LiveRoomShareOption({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.width = 72,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double width;

  @override
  Widget build(BuildContext context) {
    final content = Opacity(
      opacity: enabled ? 1 : 0.38,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: AppSpacing.shareCircleLabelGap),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.shareItemLabel.copyWith(
                color: enabled
                    ? AppColors.shareLabel
                    : AppColors.shareDisabled,
              ),
            ),
          ],
        ),
      ),
    );

    if (!enabled || onTap == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

/// Standard filled circle used by social / action rows.
class LiveRoomShareCircle extends StatelessWidget {
  const LiveRoomShareCircle({
    super.key,
    required this.background,
    required this.child,
    this.border,
  });

  final Color background;
  final Widget child;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.shareCircle,
      height: AppSizes.shareCircle,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
