import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';

/// Shared semi-transparent pill used across live-room overlays.
class LiveRoomPill extends StatelessWidget {
  const LiveRoomPill({
    super.key,
    required this.child,
    this.height = AppSizes.roomPillHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    this.color = AppColors.overlayPill,
    this.borderRadius = AppSizes.radiusPill,
  });

  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}
