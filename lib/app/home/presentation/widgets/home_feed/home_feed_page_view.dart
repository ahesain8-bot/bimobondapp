import 'package:bimobondapp/app/home/presentation/pages/live_details_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/video_post_widget.dart';
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
      physics: const OnePageScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: feedItems.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final item = feedItems[index];
        final post = item.post;
        if (post.isAuctionable) {
          return LiveDetailsScreen(post: post, embeddedInFeed: true);
        }
        return VideoPostWidget(
          key: ValueKey(item.id),
          post: post,
          feedItem: item,
          isActive: isTabActive && index == currentPostIndex,
          bottomPadding: HomeLayoutConstants.feedPostBottomPadding,
        );
      },
    );
  }
}
