import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post_widget.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_auction_preview.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/utils/one_page_scroll_physics.dart';
import 'package:flutter/material.dart';

class HomeFeedPageView extends StatelessWidget {
  const HomeFeedPageView({
    required this.controller,
    required this.feedItems,
    required this.currentPostIndex,
    required this.isTabActive,
    required this.onPageChanged,
    super.key,
  });

  final PageController controller;
  final List<FeedItemEntity> feedItems;
  final int currentPostIndex;
  final bool isTabActive;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      // Don't keep adjacent page States alive with live decoders — that
      // exhausts Android MediaCodec. Scroll-back uses the prewarmer pool.
      allowImplicitScrolling: false,
      physics: const OnePageScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: feedItems.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final item = feedItems[index];
        final post = item.post;
        if (post.isAuctionable) {
          return FeedAuctionPreview(
            key: ValueKey(item.id),
            post: post,
            bottomPadding: HomeLayoutConstants.feedPostBottomPadding,
            feedTopBarClearance:
                HomeLayoutConstants.feedTopBarHeight +
                HomeLayoutConstants.feedTopBarBottomGap,
          );
        }
        return VideoPostWidget(
          key: ValueKey(item.id),
          post: post,
          feedItem: item,
          isActive: isTabActive && index == currentPostIndex,
          bottomPadding: HomeLayoutConstants.feedPostBottomPadding,
          feedTopBarClearance:
              HomeLayoutConstants.feedTopBarHeight +
              HomeLayoutConstants.feedTopBarBottomGap,
          pageController: controller,
          pageIndex: index,
        );
      },
    );
  }
}
