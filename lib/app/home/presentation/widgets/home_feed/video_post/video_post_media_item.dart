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
    this.onImageMuteTap,
    this.isImageMuted = false,
    this.onPlaybackChanged,
    this.onSeekSync,
    this.onUserMuteChanged,
    this.onSegmentEnd,
    this.onVideoDurationReady,
    this.segmentPlaybackMax,
    this.mediaFit = BoxFit.contain,
    this.mediaHeight,
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
  final VoidCallback? onImageMuteTap;
  final bool isImageMuted;
  final VoidCallback? onPlaybackChanged;
  final FeedVideoSeekSync? onSeekSync;
  final ValueChanged<bool>? onUserMuteChanged;
  final VoidCallback? onSegmentEnd;
  final ValueChanged<Duration>? onVideoDurationReady;
  final Duration? segmentPlaybackMax;
  final BoxFit mediaFit;
  final double? mediaHeight;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = MediaUtils.resolveAbsoluteUrl(media.url);
    final isVideo =
        MediaUtils.isVideo(mediaUrl, mediaType: media.mediaType) ||
        post.type == 'VIDEO';
    // Prefer HLS when available (adaptive bitrate); MP4 as fallback URL.
    final playbackUrl = isVideo && index == 0
        ? (MediaUtils.resolveFeedPlaybackVideoUrl(post) ?? mediaUrl)
        : mediaUrl;
    final fallbackPlaybackUrl = isVideo && index == 0
        ? _feedVideoFallbackUrl(post, primaryUrl: playbackUrl)
        : null;
    final hasAttachedSound = post.sound?.resolvedAudioUrl?.isNotEmpty ?? false;
    final sound = post.sound;
    final hasSegmentWindow = sound?.hasSegmentWindow ?? false;
    final segmentMaxPosition =
        segmentPlaybackMax ??
        (hasSegmentWindow
            ? Duration(milliseconds: sound!.endMs! - sound.startMs!)
            : null);

    Widget child = isVideo
        ? CustomVideoPlayer(
            url: playbackUrl,
            fallbackUrl: fallbackPlaybackUrl,
            posterUrl: MediaUtils.resolveVideoPosterUrl(post),
            isActive: isActiveSlide,
            respectFeedPlaybackGate: respectFeedPlaybackGate,
            muteAudio: hasAttachedSound,
            loopVideo: !hasSegmentWindow,
            segmentMaxPosition: hasAttachedSound ? segmentMaxPosition : null,
            controller: videoController,
            onLongPress: onLongPress,
            onPlaybackChanged: hasAttachedSound ? onPlaybackChanged : null,
            onSeekSync: hasAttachedSound ? onSeekSync : null,
            onUserMuteChanged: hasAttachedSound ? onUserMuteChanged : null,
            onSegmentEnd: hasAttachedSound ? onSegmentEnd : null,
            onVideoDurationReady: hasAttachedSound
                ? onVideoDurationReady
                : null,
          )
        : mediaUrl.isEmpty
        ? const Icon(LucideIcons.imageOff, size: 80, color: Colors.white24)
        : SafeNetworkImage(
            imageUrl: mediaUrl,
            fit: mediaFit,
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
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onImageMuteTap != null)
                            GestureDetector(
                              onTap: onImageMuteTap,
                              child: BlurredIconBadge(
                                icon: isImageMuted
                                    ? LucideIcons.volumeX
                                    : LucideIcons.volume2,
                                diameter: 40,
                                iconSize: 22,
                                iconColor: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          if (onImageMuteTap != null) const SizedBox(height: 12),
                          BlurredIconBadge(
                            icon: LucideIcons.play,
                            diameter: 88,
                            iconSize: 44,
                            iconColor: Colors.white.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            : child,
      );
    }

    final itemHeight = mediaHeight ?? MediaQuery.sizeOf(context).height;

    return SizedBox(
      key: ValueKey('${playbackUrl}_$index'),
      width: MediaQuery.sizeOf(context).width,
      height: itemHeight,
      child: Center(child: child),
    );
  }

  /// Alternate stream when the primary URL fails (HLS ↔ progressive).
  static String? _feedVideoFallbackUrl(
    PostEntity post, {
    required String primaryUrl,
  }) {
    final resolvedPrimary = MediaUtils.resolveAbsoluteUrl(primaryUrl);
    final progressive = MediaUtils.resolveFeedProgressiveVideoUrl(post);
    final hls = post.hlsUrl?.trim();
    final resolvedHls = hls != null && hls.isNotEmpty
        ? MediaUtils.resolveAbsoluteUrl(hls)
        : null;

    if (resolvedHls != null &&
        resolvedHls != resolvedPrimary &&
        resolvedPrimary.toLowerCase().contains('.m3u8')) {
      return progressive;
    }
    if (progressive != null &&
        progressive.isNotEmpty &&
        progressive != resolvedPrimary) {
      return progressive;
    }
    if (resolvedHls != null &&
        resolvedHls.isNotEmpty &&
        resolvedHls != resolvedPrimary) {
      return resolvedHls;
    }
    return null;
  }
}
