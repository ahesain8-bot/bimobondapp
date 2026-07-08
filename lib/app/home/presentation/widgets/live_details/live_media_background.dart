import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LiveMediaBackground extends StatelessWidget {
  const LiveMediaBackground({
    required this.mediaItems,
    required this.pageController,
    required this.onPageChanged,
    required this.currentIndex,
    this.posterUrl,
    this.isActive = true,
    super.key,
  });

  final List<PostMediaEntity> mediaItems;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final int currentIndex;
  final String? posterUrl;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }

    if (mediaItems.length <= 1) {
      return _buildMediaItem(mediaItems.first, 0);
    }

    return PageView.builder(
      controller: pageController,
      itemCount: mediaItems.length,
      onPageChanged: onPageChanged,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) => _buildMediaItem(mediaItems[index], index),
    );
  }

  Widget _buildMediaItem(PostMediaEntity media, int index) {
    final url = MediaUtils.resolveAbsoluteUrl(media.url);
    final isVideo = MediaUtils.isVideo(url, mediaType: media.mediaType);

    if (isVideo) {
      return CustomVideoPlayer(
        key: ValueKey('auction_media_video_$url'),
        url: url,
        posterUrl: posterUrl,
        isActive: isActive && currentIndex == index,
        respectFeedPlaybackGate: false,
      );
    }

    if (url.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }

    return SafeNetworkImage(
      key: ValueKey('auction_media_image_$url'),
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorIcon: LucideIcons.imageOff,
    );
  }
}
