import 'package:flutter/material.dart';

/// Static preview for video posts (black background + play icon).
class VideoPostPreviewPlaceholder extends StatelessWidget {
  const VideoPostPreviewPlaceholder({
    super.key,
    this.iconSize = 34,
    this.icon = Icons.play_arrow_rounded,
  });

  final double iconSize;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
