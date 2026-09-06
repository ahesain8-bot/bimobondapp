import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/live_interactive.dart';

/// Progress bar for the stream gift goal (`lives/mobile-api.md` §A).
///
/// Every number here comes from the server — the POST response or the
/// `liveGiftGoalUpdate` event. Nothing is accumulated locally, so a gift can
/// never be counted twice, and the bar never shows completion before the
/// server says so.
class LiveGiftGoalBar extends StatelessWidget {
  const LiveGiftGoalBar({super.key, required this.goal});

  final LiveGiftGoal goal;

  @override
  Widget build(BuildContext context) {
    // A non-positive target is not a goal; the caller filters it out, and this
    // guard keeps the division safe if it ever slips through.
    if (goal.target <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final goalLabel = l10n?.liveGiftGoalLabel ?? '';
    final reached = goal.current >= goal.target;
    // Clamped for painting only. The label keeps the server's real numbers.
    final progress = (goal.current / goal.target).clamp(0.0, 1.0);
    final title = goal.title?.trim();

    return Semantics(
      container: true,
      label: goalLabel,
      value: '${goal.current}/${goal.target} ${l10n?.coinsUnit ?? ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.emoji_events : Icons.flag_outlined,
                size: 14,
                color: Colors.amberAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title == null || title.isEmpty ? goalLabel : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Directionality-neutral so Arabic layouts keep "current/target".
              Text(
                '${goal.current}/${goal.target}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                reached ? Colors.amberAccent : Colors.pinkAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
