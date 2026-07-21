import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/blurred_icon_badge.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoPostMediaItem extends StatelessWidget {
  const VideoPostMediaItem({
    required this.media,
    required this.index,
    required this.post,
    required this.isActiveSlide,
    required this.respectFeedPlaybackGate,
    required this.videoController,
    required this.isImagePlaybackActive,
    required this.onLongPress,
    this.onImageTap,
    super.key,
  });

  final PostMediaEntity media;
  final int index;
  final PostEntity post;
  final bool isActiveSlide;
  final bool respectFeedPlaybackGate;
  final CustomVideoPlayerController videoController;
  final bool isImagePlaybackActive;
  final VoidCallback onLongPress;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = MediaUtils.resolveAbsoluteUrl(media.url);
    final isVideo =
        MediaUtils.isVideo(mediaUrl, mediaType: media.mediaType) ||
        post.type == 'VIDEO';
    // Prefer the adaptive HLS rendition for the post's primary video. Keep
    // each item's own URL for later carousel slides, because the post-level
    // HLS URL represents only the primary video.
    final hlsUrl = post.hlsUrl?.trim();
    final playbackUrl = isVideo && index == 0 && hlsUrl?.isNotEmpty == true
        ? MediaUtils.resolveAbsoluteUrl(hlsUrl!)
        : mediaUrl;

    Widget child = isVideo
        ? CustomVideoPlayer(
            url: playbackUrl,
            posterUrl: MediaUtils.resolveVideoPosterUrl(post),
            isActive: isActiveSlide,
            respectFeedPlaybackGate: respectFeedPlaybackGate,
            controller: videoController,
            onLongPress: onLongPress,
          )
        : mediaUrl.isEmpty
        ? const Icon(LucideIcons.imageOff, size: 80, color: Colors.white24)
        : SafeNetworkImage(
            imageUrl: mediaUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorIcon: LucideIcons.imageOff,
          );

    if (!isVideo) {
      child = GestureDetector(
        onTap: onImageTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: onImageTap != null
            ? Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  child,
                  if (!isImagePlaybackActive)
                    BlurredIconBadge(
                      icon: LucideIcons.play,
                      diameter: 88,
                      iconSize: 44,
                      iconColor: Colors.white.withValues(alpha: 0.85),
                    ),
                ],
              )
            : child,
      );
    }

    return SizedBox(
      key: ValueKey('${playbackUrl}_$index'),
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      child: Center(child: child),
    );
  }
}
