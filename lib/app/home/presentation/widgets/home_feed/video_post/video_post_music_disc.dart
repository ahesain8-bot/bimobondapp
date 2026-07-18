import 'dart:ui';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoPostMusicDisc extends StatelessWidget {
  const VideoPostMusicDisc({
    required this.rotation,
    this.onTap,
    super.key,
  });

  final Animation<double> rotation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: rotation,
        builder: (context, child) {
          return Transform.rotate(
            angle: rotation.value * 2 * 3.14159,
            child: child,
          );
        },
        child: Container(
          width: VideoPostLayoutConstants.musicDiscSize,
          height: VideoPostLayoutConstants.musicDiscSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.8),
                theme.colorScheme.secondary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.music,
                    color: Colors.white70,
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
