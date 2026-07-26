import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Static disc (no rotation): avoids a permanent 60fps ticker per post.
class VideoPostMusicDisc extends StatelessWidget {
  const VideoPostMusicDisc({
    this.soundCoverUrl,
    this.avatarUrl,
    this.onTap,
    this.showSoundIcon = false,
    this.soundIconData = LucideIcons.music,
    super.key,
  });

  final String? soundCoverUrl;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final bool showSoundIcon;
  final IconData soundIconData;

  @override
  Widget build(BuildContext context) {
    final size = VideoPostLayoutConstants.musicDiscSize;
    final centerSize = size * 0.52;
    final resolvedCover = (soundCoverUrl?.trim().isNotEmpty == true)
        ? soundCoverUrl!.trim()
        : (avatarUrl?.trim().isNotEmpty == true ? avatarUrl!.trim() : null);

    return GestureDetector(
      onTap: onTap,
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
          child: resolvedCover != null && resolvedCover.isNotEmpty
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    SafeNetworkImage(
                      imageUrl: resolvedCover,
                      width: centerSize,
                      height: centerSize,
                      fit: BoxFit.cover,
                    ),
                    if (showSoundIcon) ...[
                      Container(
                        color: Colors.black38,
                      ),
                      Icon(
                        soundIconData,
                        color: Colors.white,
                        size: centerSize * 0.55,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              : Icon(
                  soundIconData,
                  color: Colors.white70,
                  size: 16,
                ),
        ),
      ),
    );
  }
}
