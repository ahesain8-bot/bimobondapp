import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

/// Gradient or gray ring around an avatar when the user has active stories.
///
/// [radius] is the **outer** radius (including the ring), so overall size matches
/// a plain [SafeNetworkAvatar] with the same [radius].
class StoryRingAvatar extends StatelessWidget {
  const StoryRingAvatar({
    required this.imageUrl,
    required this.fallbackText,
    required this.theme,
    required this.radius,
    this.isViewed = false,
    this.ringWidth = 2.5,
    this.ringGap = 2.0,
    super.key,
  });

  final String? imageUrl;
  final String fallbackText;
  final ThemeData theme;
  final double radius;
  final bool isViewed;
  final double ringWidth;
  final double ringGap;

  @override
  Widget build(BuildContext context) {
    final grayRing = theme.colorScheme.onSurface.withValues(alpha: 0.28);
    final size = radius * 2;
    final imageRadius =
        (radius - ringWidth - ringGap).clamp(1.0, radius);

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isViewed
              ? null
              : LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.3),
                  ],
                ),
          color: isViewed ? grayRing : null,
        ),
        padding: EdgeInsets.all(ringWidth),
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(ringGap),
          alignment: Alignment.center,
          child: SafeNetworkAvatar(
            imageUrl: imageUrl,
            radius: imageRadius,
            fallbackText: fallbackText,
          ),
        ),
      ),
    );
  }
}
