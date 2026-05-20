import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:flutter/material.dart';

class FeedVideoProgressBar extends StatelessWidget {
  const FeedVideoProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final feedOverlay = FeedOverlayTheme.of(context);
    final notifier = FeedVideoProgressScope.maybeOf(context);

    if (notifier == null) {
      return LinearProgressIndicator(
        value: 0,
        backgroundColor: feedOverlay.progressTrack,
        valueColor: AlwaysStoppedAnimation<Color>(feedOverlay.progressFill),
        minHeight: HomeLayoutConstants.progressBarMinHeight,
      );
    }

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        return LinearProgressIndicator(
          value: notifier.hasDuration ? notifier.progress : 0,
          backgroundColor: feedOverlay.progressTrack,
          valueColor: AlwaysStoppedAnimation<Color>(feedOverlay.progressFill),
          minHeight: HomeLayoutConstants.progressBarMinHeight,
        );
      },
    );
  }
}
