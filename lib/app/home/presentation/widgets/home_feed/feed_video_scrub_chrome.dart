import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_posts_viewer_layout.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:flutter/material.dart';

/// Hides [child] while the user scrubs the feed progress bar (TikTok-style).
class FeedVideoHideWhenScrubbing extends StatelessWidget {
  const FeedVideoHideWhenScrubbing({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final notifier = FeedVideoProgressScope.maybeOf(context);
    if (notifier == null) return child;

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        if (notifier.scrubbing) return const SizedBox.shrink();
        return child;
      },
    );
  }
}

/// Bottom offset so search + progress match profile posts viewer stacking.
double feedVideoProgressBottomOffset(BuildContext context) {
  return FeedVideoPostsViewerLayout.progressColumnBottom(
    FeedVideoPostsViewerLayout.homeBottomNavStackHeight(context),
  );
}