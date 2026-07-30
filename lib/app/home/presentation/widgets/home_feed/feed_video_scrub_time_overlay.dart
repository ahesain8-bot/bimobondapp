import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:flutter/material.dart';

/// Large centered `00:19 / 00:58` while scrubbing the feed progress bar.
class FeedVideoScrubTimeOverlay extends StatelessWidget {
  const FeedVideoScrubTimeOverlay({super.key});

  static String _formatClock(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 3600);
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final notifier = FeedVideoProgressScope.maybeOf(context);
    if (notifier == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        if (!notifier.scrubbing || !notifier.hasDuration) {
          return const SizedBox.shrink();
        }

        final progress = notifier.displayProgress.clamp(0.0, 1.0);
        final currentMs =
            (progress * notifier.duration.inMilliseconds).round();
        final current = Duration(milliseconds: currentMs);
        final total = notifier.duration;

        return IgnorePointer(
          child: Center(
            child: Text(
              '${_formatClock(current)} / ${_formatClock(total)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: const [
                  Shadow(
                    blurRadius: 16,
                    color: Colors.black54,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
