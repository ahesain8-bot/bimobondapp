import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted circular/pill icon badge used on post media overlays.
class BlurredIconBadge extends StatelessWidget {
  const BlurredIconBadge({
    required this.icon,
    super.key,
    this.diameter = 56,
    this.iconSize,
    this.iconColor = Colors.white,
    this.blurSigma = 14,
    this.backgroundOpacity = 0.35,
    this.borderOpacity = 0.22,
    this.padding,
    this.borderRadius,
  });

  final IconData icon;
  final double diameter;
  final double? iconSize;
  final Color iconColor;
  final double blurSigma;
  final double backgroundOpacity;
  final double borderOpacity;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? diameter * 0.46;
    final resolvedRadius =
        borderRadius ?? BorderRadius.circular(diameter / 2);
    final resolvedPadding =
        padding ?? EdgeInsets.all((diameter - resolvedIconSize) / 2);

    return ClipRRect(
      borderRadius: resolvedRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: borderRadius == null ? diameter : null,
          height: borderRadius == null ? diameter : null,
          padding: resolvedPadding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: backgroundOpacity),
            borderRadius: resolvedRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
            ),
          ),
          child: Icon(icon, size: resolvedIconSize, color: iconColor),
        ),
      ),
    );
  }
}
