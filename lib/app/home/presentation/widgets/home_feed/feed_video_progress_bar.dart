import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:flutter/material.dart';

/// Scrubbable feed progress strip — tap or drag to seek within the video.
class FeedVideoProgressBar extends StatefulWidget {
  const FeedVideoProgressBar({super.key});

  @override
  State<FeedVideoProgressBar> createState() => _FeedVideoProgressBarState();
}

class _FeedVideoProgressBarState extends State<FeedVideoProgressBar> {
  FeedVideoProgressNotifier? _notifier;

  double _progressForDx(double dx, double width) {
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0);
  }

  void _startScrub(Offset local, double width) {
    final notifier = _notifier;
    if (notifier == null || !notifier.canSeek) return;
    notifier.beginScrub(_progressForDx(local.dx, width));
  }

  void _updateScrub(Offset local, double width) {
    final notifier = _notifier;
    if (notifier == null || !notifier.scrubbing) return;
    notifier.updateScrub(_progressForDx(local.dx, width));
  }

  void _endScrub({required bool commit}) {
    final notifier = _notifier;
    if (notifier == null || !notifier.scrubbing) return;
    unawaited(notifier.endScrub(commit: commit));
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 3600);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final feedOverlay = FeedOverlayTheme.of(context);
    final notifier = FeedVideoProgressScope.maybeOf(context);
    _notifier = notifier;

    if (notifier == null) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: HomeLayoutConstants.progressBarHitHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: LinearProgressIndicator(
              value: 0,
              backgroundColor: feedOverlay.progressTrack,
              valueColor: AlwaysStoppedAnimation<Color>(
                feedOverlay.progressFill,
              ),
              minHeight: HomeLayoutConstants.progressBarMinHeight,
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

        // Keep the timeline LTR (left = start, right = end) even in Arabic.
        // RTL was mirroring the fill while scrub still used raw dx → opposite.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: HomeLayoutConstants.progressBarHitHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Claim vertical gestures so the feed PageView does not scroll
                  // while the user is scrubbing the timeline.
                  onVerticalDragStart: notifier.canSeek
                      ? (details) => _startScrub(details.localPosition, width)
                      : null,
                  onVerticalDragUpdate: notifier.canSeek
                      ? (details) => _updateScrub(details.localPosition, width)
                      : null,
                  onVerticalDragEnd: notifier.canSeek
                      ? (_) => _endScrub(commit: true)
                      : null,
                  onVerticalDragCancel: notifier.canSeek
                      ? () => _endScrub(commit: false)
                      : null,
                  onHorizontalDragStart: notifier.canSeek
                      ? (details) => _startScrub(details.localPosition, width)
                      : null,
                  onHorizontalDragUpdate: notifier.canSeek
                      ? (details) => _updateScrub(details.localPosition, width)
                      : null,
                  onHorizontalDragEnd: notifier.canSeek
                      ? (_) => _endScrub(commit: true)
                      : null,
                  onHorizontalDragCancel: notifier.canSeek
                      ? () => _endScrub(commit: false)
                      : null,
                  onTapDown: notifier.canSeek
                      ? (details) {
                          final p = _progressForDx(
                            details.localPosition.dx,
                            width,
                          );
                          notifier.beginScrub(p);
                          unawaited(notifier.endScrub(commit: true));
                        }
                      : null,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      if (scrubbing && notifier.hasDuration)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom:
                              HomeLayoutConstants.progressBarScrubHeight + 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(
                                  Duration(
                                    milliseconds:
                                        (progress *
                                                notifier
                                                    .duration
                                                    .inMilliseconds)
                                            .round(),
                                  ),
                                ),
                                style: TextStyle(
                                  color: feedOverlay.overlayForeground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 6,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatDuration(notifier.duration),
                                style: TextStyle(
                                  color: feedOverlay.overlayForegroundMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 6,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          height: barHeight,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(barHeight),
                            child: LinearProgressIndicator(
                              value: notifier.hasDuration ? progress : 0,
                              backgroundColor: feedOverlay.progressTrack,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                feedOverlay.progressFill,
                              ),
                              minHeight: barHeight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
