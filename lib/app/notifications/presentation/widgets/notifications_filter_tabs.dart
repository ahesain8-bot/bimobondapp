import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum NotificationsReadFilter { all, unread, read }

class NotificationsFilterTabs extends StatelessWidget {
  const NotificationsFilterTabs({
    required this.filter,
    required this.unreadCount,
    required this.onFilterSelected,
    super.key,
  });

  final NotificationsReadFilter filter;
  final int unreadCount;
  final ValueChanged<NotificationsReadFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p4,
        AppSizes.p16,
        AppSizes.p12,
      ),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _FilterTab(
                label: l10n.notificationsFilterAll,
                selected: filter == NotificationsReadFilter.all,
                onTap: () => onFilterSelected(NotificationsReadFilter.all),
              ),
            ),
            Expanded(
              child: _FilterTab(
                label: l10n.notificationsFilterUnread,
                selected: filter == NotificationsReadFilter.unread,
                badgeCount: unreadCount,
                onTap: () => onFilterSelected(NotificationsReadFilter.unread),
              ),
            ),
            Expanded(
              child: _FilterTab(
                label: l10n.notificationsFilterRead,
                selected: filter == NotificationsReadFilter.read,
                onTap: () => onFilterSelected(NotificationsReadFilter.read),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? theme.cardColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : MessagesLayoutConstants.activityBadgeColor
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? theme.colorScheme.primary
                          : MessagesLayoutConstants.activityBadgeColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
