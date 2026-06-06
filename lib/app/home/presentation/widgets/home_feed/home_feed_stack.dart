import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_overlay_controls.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_page_view.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:flutter/material.dart';

class HomeFeedStack extends StatelessWidget {
  const HomeFeedStack({
    required this.pageController,
    required this.posts,
    required this.currentPostIndex,
    required this.isTabActive,
    required this.onPageChanged,
    required this.onLiveTap,
    required this.onSearchTap,
    super.key,
  });

  final PageController pageController;
  final List<PostEntity> posts;
  final int currentPostIndex;
  final bool isTabActive;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onLiveTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final currentPost = posts[currentPostIndex.clamp(0, posts.length - 1)];
    final isAuctionPost = currentPost.isAuctionable;
    final showVideoProgress = !isAuctionPost && feedPostHasVideo(currentPost);

    return Stack(
      fit: StackFit.expand,
      children: [
        HomeFeedPageView(
          controller: pageController,
          posts: posts,
          currentPostIndex: currentPostIndex,
          isTabActive: isTabActive,
          onPageChanged: onPageChanged,
        ),
        if (!isAuctionPost)
          FeedOverlayControls(
            onLiveTap: onLiveTap,
            onSearchTap: onSearchTap,
          ),
        if (showVideoProgress)
          Positioned(
            key: ValueKey(posts[currentPostIndex].id),
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom,
            child: const FeedVideoProgressBar(),
          ),
      ],
    );
  }
}
