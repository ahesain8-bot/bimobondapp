import 'package:bimobondapp/app/notifications/presentation/utils/notification_category_filter.dart';
import 'package:bimobondapp/core/constants/notifications_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class NotificationsFilterTabs extends StatelessWidget {
  const NotificationsFilterTabs({
    required this.filter,
    required this.onFilterSelected,
    super.key,
  });

  final NotificationsCategoryFilter filter;
  final ValueChanged<NotificationsCategoryFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final filters = [
      (NotificationsCategoryFilter.all, l10n.notificationsFilterViewAll),
      (NotificationsCategoryFilter.activity, l10n.notificationsFilterActivity),
      (NotificationsCategoryFilter.auctions, l10n.notificationsFilterAuctions),
      (NotificationsCategoryFilter.invites, l10n.notificationsFilterInvites),
    ];

    return SizedBox(
      height: NotificationsLayoutConstants.chipHeight + AppSizes.p8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          NotificationsLayoutConstants.cardPadding,
          0,
          NotificationsLayoutConstants.cardPadding,
          AppSizes.p8,
        ),
        itemCount: filters.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: NotificationsLayoutConstants.chipSpacing),
        itemBuilder: (context, index) {
          final (category, label) = filters[index];
          return _FilterChip(
            label: label,
            selected: filter == category,
            onTap: () => onFilterSelected(category),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.cardColor
          : NotificationsLayoutConstants.chipUnselectedBackground(theme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          NotificationsLayoutConstants.chipRadius,
        ),
        side: selected
            ? BorderSide(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                    : NotificationsLayoutConstants.chipSelectedBorderLight,
              )
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NotificationsLayoutConstants.chipHorizontalPadding,
          ),
          child: SizedBox(
            height: NotificationsLayoutConstants.chipHeight,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
