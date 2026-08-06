import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_interest_prompt_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_posts_viewer_layout.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_scrub_time_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_search_progress_column.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_page_view.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:flutter/material.dart';

/// Home feed stack: full-bleed media + search/progress docked on the post bottom.
class HomeFeedStack extends StatelessWidget {
  const HomeFeedStack({
    required this.pageController,
    required this.feedItems,
    required this.currentPostIndex,
    required this.isTabActive,
    required this.onPageChanged,
    required this.bottomChromeListenable,
    required this.mediaBottomInsetFor,
    this.onFeedPostPatch,
    this.trafficSource = TrafficSource.forYou,
    this.showInterestPrompt = false,
    this.onInterestPromptYes,
    this.onInterestPromptNo,
    this.onInterestPromptDismiss,
    super.key,
  });

  final PageController pageController;
  final List<FeedItemEntity> feedItems;
  final int currentPostIndex;
  final bool isTabActive;
  final ValueChanged<int> onPageChanged;
  final Listenable bottomChromeListenable;
  final double Function(BuildContext context, PostEntity post)
      mediaBottomInsetFor;
  final FeedPostPatch? onFeedPostPatch;
  final String trafficSource;
  final bool showInterestPrompt;
  final VoidCallback? onInterestPromptYes;
  final VoidCallback? onInterestPromptNo;
  final VoidCallback? onInterestPromptDismiss;

  @override
  Widget build(BuildContext context) {
    final navBottom =
        FeedVideoPostsViewerLayout.homeFeedPostStackChromeBottom(context);
    final promptLift =
        showInterestPrompt ? HomeLayoutConstants.feedInterestPromptHeight : 0.0;
    final chromeBottom = navBottom + promptLift;

    return ListenableBuilder(
      listenable: bottomChromeListenable,
      builder: (context, _) {
        final current =
            feedItems[currentPostIndex.clamp(0, feedItems.length - 1)];
        final showPostStackChrome = isTabActive && !current.post.isAuctionable;

        final currentHasVideo = feedPostHasVideo(current.post);

        return Stack(
          fit: StackFit.expand,
          children: [
            HomeFeedPageView(
              controller: pageController,
              feedItems: feedItems,
              currentPostIndex: currentPostIndex,
              isTabActive: isTabActive,
              onPageChanged: onPageChanged,
              bottomChromeListenable: bottomChromeListenable,
              mediaBottomInsetFor: mediaBottomInsetFor,
              onFeedPostPatch: onFeedPostPatch,
              trafficSource: trafficSource,
            ),
            const Positioned.fill(child: FeedVideoScrubTimeOverlay()),
            if (showPostStackChrome)
              Positioned(
                key: ValueKey('feed_stack_chrome_${current.post.id}'),
                left: 0,
                right: 0,
                bottom: chromeBottom,
                child: FeedVideoSearchProgressColumn(
                  post: current.post,
                  transparentBackground: true,
                  showProgressBar: currentHasVideo,
                ),
              ),
            if (showInterestPrompt &&
                onInterestPromptYes != null &&
                onInterestPromptNo != null &&
                onInterestPromptDismiss != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: navBottom,
                child: FeedInterestPromptBar(
                  onInterested: onInterestPromptYes!,
                  onNotInterested: onInterestPromptNo!,
                  onDismiss: onInterestPromptDismiss!,
                ),
              ),
          ],
        );
      },
    );
  }
}
