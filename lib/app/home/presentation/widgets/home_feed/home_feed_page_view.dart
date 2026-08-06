import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_posts_viewer_layout.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post_widget.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_auction_preview.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/core/utils/one_page_scroll_physics.dart';
import 'package:flutter/material.dart';

class HomeFeedPageView extends StatelessWidget {
  const HomeFeedPageView({
    required this.controller,
    required this.feedItems,
    required this.currentPostIndex,
    required this.isTabActive,
    required this.onPageChanged,
    required this.bottomChromeListenable,
    required this.mediaBottomInsetFor,
    this.onFeedPostPatch,
    this.trafficSource = TrafficSource.forYou,
    super.key,
  });

  final PageController controller;
  final List<FeedItemEntity> feedItems;
  final int currentPostIndex;
  final bool isTabActive;
  final ValueChanged<int> onPageChanged;
  final Listenable bottomChromeListenable;
  final double Function(BuildContext context, PostEntity post)
      mediaBottomInsetFor;
  final FeedPostPatch? onFeedPostPatch;
  final String trafficSource;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bottomChromeListenable,
      builder: (context, _) {
        return PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          allowImplicitScrolling: false,
          physics: const OnePageScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: feedItems.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            final item = feedItems[index];
            final post = item.post;
            final navHeight =
                FeedVideoPostsViewerLayout.homeBottomNavStackHeight(context);
            final mediaInset = mediaBottomInsetFor(context, post);
            final contentBottom = post.isAuctionable
                ? FeedVideoPostsViewerLayout.videoContentBottomPadding(
                    bottomChromeStackHeight: navHeight,
                    post: post,
                  )
                : FeedVideoPostsViewerLayout.homeFeedPostStackOverlayBottomPadding(
                    context,
                    post,
                  );

            if (post.isAuctionable) {
              return FeedAuctionPreview(
                key: ValueKey(item.id),
                post: post,
                bottomPadding:
                    FeedVideoPostsViewerLayout.videoContentBottomPadding(
                      bottomChromeStackHeight: navHeight,
                      post: post,
                    ),
                feedTopBarClearance:
                    HomeLayoutConstants.feedTopBarHeight +
                    HomeLayoutConstants.feedTopBarBottomGap,
                trafficSource: trafficSource,
              );
            }
            return VideoPostWidget(
              key: ValueKey(item.id),
              post: post,
              feedItem: item,
              isActive: isTabActive && index == currentPostIndex,
              bottomPadding: contentBottom,
              mediaBottomInset: mediaInset,
              feedMediaFit: BoxFit.cover,
              feedTopBarClearance:
                  HomeLayoutConstants.feedTopBarHeight +
                  HomeLayoutConstants.feedTopBarBottomGap,
              pageController: controller,
              pageIndex: index,
              onFeedPostPatch: onFeedPostPatch,
              trafficSource: trafficSource,
            );
          },
        );
      },
    );
  }
}
