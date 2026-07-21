import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoPostMusicDisc extends StatelessWidget {
  const VideoPostMusicDisc({
    required this.rotation,
    this.avatarUrl,
    this.onTap,
    super.key,
  });

  final Animation<double> rotation;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = VideoPostLayoutConstants.musicDiscSize;
    final centerSize = size * 0.52;
    final resolvedAvatar = avatarUrl?.trim();

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
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2A2A2A),
                Color(0xFF111111),
                Color(0xFF3A3A3A),
                Color(0xFF1A1A1A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: centerSize,
            height: centerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: resolvedAvatar != null && resolvedAvatar.isNotEmpty
                ? SafeNetworkImage(
                    imageUrl: resolvedAvatar,
                    width: centerSize,
                    height: centerSize,
                    fit: BoxFit.cover,
                  )
                : const Icon(
                    LucideIcons.music,
                    color: Colors.white70,
                    size: 12,
                  ),
          ),
        ),
      ),
    );
  }
}
