import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_search_progress_column.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:flutter/widgets.dart';

/// Shared stack layout for home feed and profile fullscreen posts (search + progress).
abstract final class FeedVideoPostsViewerLayout {
  FeedVideoPostsViewerLayout._();

  static double _safeBottom(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  /// Height of profile comment bar + home indicator.
  static double profileCommentBarStackHeight(BuildContext context) {
    return ProfileLayoutConstants.postsViewerCommentBarHeight +
        _safeBottom(context);
  }

  /// Height of home bottom navigation (glass nav), measured from layout.
  static double homeBottomNavStackHeight(BuildContext context) {
    return HomeLayoutConstants.homeBottomNavExtent(context);
  }

  /// Bottom nav stack height used for home feed chrome (matches visible tab bar).
  static double homeFeedBottomNavReservedHeight(BuildContext context) {
    return HomeLayoutConstants.homeFeedBottomBarReservedHeight(context);
  }

  /// [Positioned] `bottom` for [FeedVideoSearchProgressColumn] on the post stack.
  static double homeFeedPostStackChromeBottom(BuildContext context) {
    return homeFeedBottomNavReservedHeight(context) +
        HomeLayoutConstants.feedPostStackChromeGapAboveNav;
  }

  /// Caption / side-action inset when search + progress sit on the post stack.
  static double homeFeedPostStackOverlayBottomPadding(
    BuildContext context,
    PostEntity post,
  ) {
    return videoContentBottomPadding(
      bottomChromeStackHeight: homeFeedBottomNavReservedHeight(context),
      post: post,
      captionGap: HomeLayoutConstants.feedCaptionGapBelowSearchChrome,
      showProgressBar: feedPostHasVideo(post),
    );
  }

  /// [Positioned] `bottom` for [FeedVideoSearchProgressColumn].
  static double progressColumnBottom(double bottomChromeStackHeight) {
    return bottomChromeStackHeight + HomeLayoutConstants.progressBarBottomInset;
  }

  /// Total height of search + progress + bottom nav (home feed media inset).
  static double homeFeedBottomUiHeight(
    BuildContext context, {
    required PostEntity post,
    required bool showSearchProgress,
  }) {
    final nav = homeFeedBottomNavReservedHeight(context);
    if (!showSearchProgress) return nav;
    return nav +
        HomeLayoutConstants.feedPostStackChromeGapAboveNav +
        FeedVideoSearchProgressColumn.totalHeight(
          post,
          showProgressBar: feedPostHasVideo(post),
        );
  }

  /// [VideoPostWidget] caption / overlay inset from physical bottom.
  static double videoContentBottomPadding({
    required double bottomChromeStackHeight,
    required PostEntity post,
    double captionGap = ProfileLayoutConstants.postsViewerBottomPadding,
    bool showProgressBar = true,
    bool showSearchRow = true,
  }) {
    return progressColumnBottom(bottomChromeStackHeight) +
        FeedVideoSearchProgressColumn.totalHeight(
          post,
          showProgressBar: showProgressBar,
          showSearchRow: showSearchRow,
        ) +
        captionGap;
  }
}
