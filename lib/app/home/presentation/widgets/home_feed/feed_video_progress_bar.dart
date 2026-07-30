import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/widgets/video_loading_indicator.dart';
import 'package:flutter/material.dart';

/// Scrubbable feed progress strip — tap or drag to seek within the video.
class FeedVideoProgressBar extends StatefulWidget {
  const FeedVideoProgressBar({super.key, this.feedColumnLayout = false});

  /// Search + progress column above bottom nav: thin layout, line flush on nav.
  final bool feedColumnLayout;

  @override
  State<FeedVideoProgressBar> createState() => _FeedVideoProgressBarState();
}

class _FeedVideoProgressBarState extends State<FeedVideoProgressBar> {
  FeedVideoProgressNotifier? _notifier;

  double _progressForDx(double dx, double barWidth) {
    if (barWidth <= 0) return 0;
    return (dx / barWidth).clamp(0.0, 1.0);
  }

  void _startScrub(double dx, double barWidth) {
    final notifier = _notifier;
    if (notifier == null || !notifier.canSeek) return;
    notifier.beginScrub(_progressForDx(dx, barWidth));
  }

  void _updateScrub(double dx, double barWidth) {
    final notifier = _notifier;
    if (notifier == null || !notifier.scrubbing) return;
    notifier.updateScrub(_progressForDx(dx, barWidth));
  }

  void _endScrub({required bool commit}) {
    final notifier = _notifier;
    if (notifier == null || !notifier.scrubbing) return;
    unawaited(notifier.endScrub(commit: commit));
  }

  Widget _buildTrack({
    required FeedOverlayTheme feedOverlay,
    required double barWidth,
    required double barHeight,
    required double progress,
    required bool showPlayhead,
  }) {
    final fill = feedOverlay.progressFill;
    final track = feedOverlay.progressTrack;
    final p = progress.clamp(0.0, 1.0);
    final fillWidth = barWidth * p;
    final dotSize = barHeight >= HomeLayoutConstants.progressBarScrubHeight
        ? HomeLayoutConstants.progressBarDotScrubSize
        : HomeLayoutConstants.progressBarDotSize;
    final dotLeft = (fillWidth - dotSize / 2).clamp(0.0, barWidth - dotSize);

    return SizedBox(
      height: barHeight,
      width: barWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
            child: SizedBox(height: barHeight, width: barWidth),
          ),
          if (showPlayhead && fillWidth > 0)
            DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(barHeight / 2),
              ),
              child: SizedBox(height: barHeight, width: fillWidth),
            ),
          if (showPlayhead && p > 0)
            Positioned(
              left: dotLeft,
              top: (barHeight - dotSize) / 2,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrubLayer({
    required FeedVideoProgressNotifier notifier,
    required FeedOverlayTheme feedOverlay,
    required double barWidth,
    required double progress,
    required bool scrubbing,
    required double barHeight,
    required Alignment trackAlignment,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: notifier.canSeek
          ? (details) => _startScrub(details.localPosition.dx, barWidth)
          : null,
      onVerticalDragUpdate: notifier.canSeek
          ? (details) => _updateScrub(details.localPosition.dx, barWidth)
          : null,
      onVerticalDragEnd: notifier.canSeek
          ? (_) => _endScrub(commit: true)
          : null,
      onVerticalDragCancel: notifier.canSeek
          ? () => _endScrub(commit: false)
          : null,
      onHorizontalDragStart: notifier.canSeek
          ? (details) => _startScrub(details.localPosition.dx, barWidth)
          : null,
      onHorizontalDragUpdate: notifier.canSeek
          ? (details) => _updateScrub(details.localPosition.dx, barWidth)
          : null,
      onHorizontalDragEnd: notifier.canSeek
          ? (_) => _endScrub(commit: true)
          : null,
      onHorizontalDragCancel: notifier.canSeek
          ? () => _endScrub(commit: false)
          : null,
      onTapDown: notifier.canSeek
          ? (details) {
              final p = _progressForDx(details.localPosition.dx, barWidth);
              notifier.beginScrub(p);
              unawaited(notifier.endScrub(commit: true));
            }
          : null,
      child: Stack(
        alignment: trackAlignment,
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            alignment: trackAlignment,
            child: _buildTrack(
              feedOverlay: feedOverlay,
              barWidth: barWidth,
              barHeight: barHeight,
              progress: progress,
              showPlayhead: notifier.hasDuration,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedOverlay = FeedOverlayTheme.of(context);
    final notifier = FeedVideoProgressScope.maybeOf(context);
    _notifier = notifier;
    final hPad = widget.feedColumnLayout
        ? HomeLayoutConstants.progressBarFeedColumnHorizontalPadding
        : HomeLayoutConstants.progressBarHorizontalPadding;
    final trackAlignment = widget.feedColumnLayout
        ? Alignment.bottomCenter
        : Alignment.bottomCenter;
    final layoutHeight = widget.feedColumnLayout
        ? HomeLayoutConstants.feedStackedProgressLayoutHeight
        : HomeLayoutConstants.progressBarHitHeight;
    final hitHeight = HomeLayoutConstants.progressBarHitHeight;

    Widget wrapHitTarget(Widget child) {
      if (!widget.feedColumnLayout) return child;
      return SizedBox(
        height: layoutHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox(height: hitHeight, width: double.infinity, child: child),
          ],
        ),
      );
    }

    if (notifier == null) {
      return wrapHitTarget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: hitHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: trackAlignment,
                    child: _buildTrack(
                      feedOverlay: feedOverlay,
                      barWidth: constraints.maxWidth,
                      barHeight: HomeLayoutConstants.progressBarMinHeight,
                      progress: 0,
                      showPlayhead: false,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final scrubbing = notifier.scrubbing;
        final progress = notifier.displayProgress;
        final barHeight = scrubbing
            ? HomeLayoutConstants.progressBarScrubHeight
            : HomeLayoutConstants.progressBarMinHeight;

        if (widget.feedColumnLayout &&
            notifier.videoLoading &&
            !scrubbing) {
          return wrapHitTarget(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: VideoLoadingIndicator(),
              ),
            ),
          );
        }

        return wrapHitTarget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: hitHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    return _buildScrubLayer(
                      notifier: notifier,
                      feedOverlay: feedOverlay,
                      barWidth: barWidth,
                      progress: progress,
                      scrubbing: scrubbing,
                      barHeight: barHeight,
                      trackAlignment: trackAlignment,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
