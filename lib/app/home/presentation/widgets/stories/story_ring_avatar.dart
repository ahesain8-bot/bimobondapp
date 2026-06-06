import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

/// Gradient or gray ring around an avatar when the user has active stories.
class StoryRingAvatar extends StatelessWidget {
  const StoryRingAvatar({
    required this.imageUrl,
    required this.fallbackText,
    required this.theme,
    required this.radius,
    this.isViewed = false,
    this.ringWidth = 2.5,
    super.key,
  });

  final String? imageUrl;
  final String fallbackText;
  final ThemeData theme;
  final double radius;
  final bool isViewed;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final grayRing = theme.colorScheme.onSurface.withValues(alpha: 0.28);

    return Container(
      padding: EdgeInsets.all(ringWidth),
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
        border: isViewed
            ? Border.all(color: grayRing, width: 2)
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: SafeNetworkAvatar(
          imageUrl: imageUrl,
          radius: radius,
          fallbackText: fallbackText,
        ),
      ),
    );
  }
}
