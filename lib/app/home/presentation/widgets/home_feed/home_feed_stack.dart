import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_top_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_page_view.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_tab.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:flutter/material.dart';

class HomeFeedStack extends StatelessWidget {
  const HomeFeedStack({
    required this.pageController,
    required this.feedItems,
    required this.currentPostIndex,
    required this.isTabActive,
    required this.selectedFeedTab,
    required this.onFeedTabChanged,
    required this.onPageChanged,
    required this.onLiveTap,
    required this.onSearchTap,
    super.key,
  });

  final PageController pageController;
  final List<FeedItemEntity> feedItems;
  final int currentPostIndex;
  final bool isTabActive;
  final HomeFeedTab selectedFeedTab;
  final ValueChanged<HomeFeedTab> onFeedTabChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onLiveTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final currentItem = feedItems[currentPostIndex.clamp(0, feedItems.length - 1)];
    final currentPost = currentItem.post;
    final isAuctionPost = currentPost.isAuctionable;
    final showVideoProgress = !isAuctionPost && feedPostHasVideo(currentPost);

    return Stack(
      fit: StackFit.expand,
      children: [
        HomeFeedPageView(
          controller: pageController,
          feedItems: feedItems,
          currentPostIndex: currentPostIndex,
          isTabActive: isTabActive,
          onPageChanged: onPageChanged,
        ),
        if (!isAuctionPost)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FeedTopBar(
              selectedTab: selectedFeedTab,
              onTabChanged: onFeedTabChanged,
              onLiveTap: onLiveTap,
              onSearchTap: onSearchTap,
            ),
          ),
        if (showVideoProgress)
          Positioned(
            key: ValueKey(feedItems[currentPostIndex].id),
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom,
            child: const FeedVideoProgressBar(),
          ),
      ],
    );
  }
}
