import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_search_hint.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_scrub_chrome.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:flutter/material.dart';

/// Bottom UI above nav: search recommendation, then progress on the nav edge.
class FeedVideoSearchProgressColumn extends StatelessWidget {
  const FeedVideoSearchProgressColumn({
    required this.post,
    this.onRequestCollapse,
    this.transparentBackground = false,
    this.showProgressBar = true,
    this.showSearchRow = true,
    super.key,
  });

  final PostEntity post;
  final VoidCallback? onRequestCollapse;

  /// When true, no black scrim — video remains visible behind search + progress.
  final bool transparentBackground;

  /// Photo posts: search row only (no scrub bar).
  final bool showProgressBar;

  /// When false, search sits elsewhere (e.g. profile top bar).
  final bool showSearchRow;

  String get _searchRecommendation => feedPostSearchRecommendation(post);

  static double totalHeight(
    PostEntity post, {
    bool showProgressBar = true,
    bool showSearchRow = true,
  }) {
    return (showProgressBar
            ? HomeLayoutConstants.feedStackedProgressLayoutHeight
            : 0) +
        (showSearchRow ? HomeLayoutConstants.feedSearchHintBarHeight : 0);
  }

  @override
  Widget build(BuildContext context) {
    final scrim = transparentBackground ? Colors.transparent : Colors.black;

    return ColoredBox(
      color: scrim,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onRequestCollapse != null)
            Material(
              color: scrim,
              child: InkWell(
                onTap: onRequestCollapse,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 22,
                  ),
                ),
              ),
            ),
          if (showSearchRow)
            FeedVideoHideWhenScrubbing(
              child: FeedPostSearchHintBar(
                recommendation: _searchRecommendation,
                embeddedInFeedChrome: true,
                alwaysShowSearchLabel: true,
              ),
            ),
          if (showProgressBar)
            FeedVideoProgressBar(
              key: ValueKey('feed_progress_${post.id}'),
              feedColumnLayout: true,
            ),
        ],
      ),
    );
  }
}
