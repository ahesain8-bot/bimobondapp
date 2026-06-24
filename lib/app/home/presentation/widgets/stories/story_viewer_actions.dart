import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bottom like + message row for story viewer.
class StoryViewerBottomActions extends StatelessWidget {
  const StoryViewerBottomActions({
    required this.isLiked,
    required this.onLike,
    this.onMessage,
    this.messageHint = '',
    super.key,
  });

  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback? onMessage;
  final String messageHint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StoryBottomChip(
          onTap: onLike,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p10,
          ),
          child: Icon(
            isLiked ? Icons.favorite : LucideIcons.heart,
            size: 22,
            color: isLiked ? Colors.red : Colors.white.withValues(alpha: 0.9),
          ),
        ),
        if (onMessage != null) ...[
          const SizedBox(width: AppSizes.p10),
          Expanded(
            child: GestureDetector(
              onTap: onMessage,
              child: _StoryBottomChip(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p16,
                  vertical: AppSizes.p10,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.send,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: AppSizes.p8),
                    Expanded(
                      child: Text(
                        messageHint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tappable viewer count for story owner (opens likes/views sheet).
class StoryViewerViewersChip extends StatelessWidget {
  const StoryViewerViewersChip({
    required this.viewCount,
    required this.label,
    required this.onTap,
    super.key,
  });

  final int viewCount;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p12,
          vertical: AppSizes.p8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.chevronUp,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: AppSizes.p4),
            Icon(
              LucideIcons.eye,
              size: 18,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: AppSizes.p6),
            Text(
              formatCompactCount(viewCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSizes.p4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryBottomChip extends StatelessWidget {
  const _StoryBottomChip({
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p10,
          ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: child,
    );

    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}
