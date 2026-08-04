import 'dart:async';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:flutter/material.dart';

import 'video_progress_controller.dart';
import 'video_progress_painter.dart';

/// TikTok-style VideoProgressBar widget that renders track, buffered progress,
/// played progress, and centered playhead dot knob using high-performance CustomPainter.
class VideoProgressBar extends StatelessWidget {
  const VideoProgressBar({
    required this.controller,
    super.key,
    this.feedColumnLayout = false,
  });

  final VideoProgressController controller;
  final bool feedColumnLayout;

  double _progressForDx(double dx, double width) {
    if (width <= 0) return 0.0;
    return (dx / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final feedOverlay = FeedOverlayTheme.of(context);
    final hPad = feedColumnLayout
        ? HomeLayoutConstants.progressBarFeedColumnHorizontalPadding
        : HomeLayoutConstants.progressBarHorizontalPadding;
    final hitHeight = HomeLayoutConstants.progressBarHitHeight;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: hitHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: controller.canSeek
                    ? (details) => controller.beginDrag(
                          _progressForDx(details.localPosition.dx, barWidth),
                        )
                    : null,
                onTapUp: controller.canSeek
                    ? (_) => unawaited(controller.endDrag(commit: true))
                    : null,
                onTapCancel: controller.canSeek
                    ? () => unawaited(controller.endDrag(commit: false))
                    : null,
                onHorizontalDragStart: controller.canSeek
                    ? (details) => controller.beginDrag(
                          _progressForDx(details.localPosition.dx, barWidth),
                        )
                    : null,
                onHorizontalDragUpdate: controller.canSeek
                    ? (details) => controller.updateDrag(
                          _progressForDx(details.localPosition.dx, barWidth),
                        )
                    : null,
                onHorizontalDragEnd: controller.canSeek
                    ? (_) => unawaited(controller.endDrag(commit: true))
                    : null,
                onHorizontalDragCancel: controller.canSeek
                    ? () => unawaited(controller.endDrag(commit: false))
                    : null,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final isDragging = controller.isDragging;
                    final barHeight = isDragging
                        ? HomeLayoutConstants.progressBarScrubHeight
                        : HomeLayoutConstants.progressBarMinHeight;
                    final dotSize = isDragging
                        ? HomeLayoutConstants.progressBarDotScrubSize
                        : 0.0;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      height: hitHeight,
                      width: barWidth,
                      alignment: Alignment.center,
                      child: CustomPaint(
                        size: Size(barWidth, hitHeight),
                        painter: VideoProgressPainter(
                          progress: controller.progress,
                          bufferedProgress: controller.bufferedProgress,
                          isDragging: isDragging,
                          trackColor: feedOverlay.progressTrack,
                          bufferedColor: Colors.white.withValues(alpha: 0.35),
                          progressColor: feedOverlay.progressFill,
                          barHeight: barHeight,
                          dotSize: dotSize,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
