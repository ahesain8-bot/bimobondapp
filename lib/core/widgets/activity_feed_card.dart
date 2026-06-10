import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

Color activityFeedCardColor(ThemeData theme) {
  return theme.brightness == Brightness.light ? Colors.white : theme.cardColor;
}

/// Card shell matching [NotificationListTile] — rounded border, shadow, type badge.
class ActivityFeedCard extends StatelessWidget {
  const ActivityFeedCard({
    required this.badgeColor,
    required this.badgeIcon,
    required this.avatar,
    required this.content,
    this.onTap,
    this.trailing,
    this.highlight = false,
  });

  final Color badgeColor;
  final IconData badgeIcon;
  final Widget avatar;
  final Widget content;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = activityFeedCardColor(theme);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p10),
      child: Material(
        color: highlight
            ? theme.colorScheme.primary.withValues(alpha: 0.04)
            : cardColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlight
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.dividerColor.withValues(alpha: 0.08),
              ),
              boxShadow: highlight
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      avatar,
                      PositionedDirectional(
                        end: -2,
                        bottom: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: badgeColor.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            badgeIcon,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(child: content),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSizes.p8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityFeedActionText extends StatelessWidget {
  const ActivityFeedActionText({
    required this.actorName,
    required this.action,
    this.time,
    this.extra,
    super.key,
  });

  final String actorName;
  final String action;
  final String? time;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  children: [
                    TextSpan(
                      text: actorName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: ' $action',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (extra != null && extra!.isNotEmpty)
                      TextSpan(
                        text: ' · $extra',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (time != null && time!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                time!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class ActivityFeedQuoteBox extends StatelessWidget {
  const ActivityFeedQuoteBox({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.3,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
