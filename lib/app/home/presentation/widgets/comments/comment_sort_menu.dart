import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CommentSortMenu extends StatelessWidget {
  const CommentSortMenu({
    required this.sort,
    required this.onSortChanged,
    super.key,
  });

  static const sortKeys = ['newest', 'oldest', 'top'];

  final String sort;
  final ValueChanged<String> onSortChanged;

  static String labelFor(String key, AppLocalizations l10n) {
    switch (key) {
      case 'oldest':
        return l10n.commentsSortOldest;
      case 'top':
        return l10n.commentsSortTop;
      case 'newest':
      default:
        return l10n.commentsSortNewest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDefaultSort = sort == 'newest';

    return PopupMenuButton<String>(
      initialValue: sort,
      tooltip: labelFor(sort, l10n),
      offset: const Offset(0, 40),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.p12),
      ),
      onSelected: onSortChanged,
      icon: Icon(
        LucideIcons.slidersHorizontal,
        size: 20,
        color: isDefaultSort
            ? theme.colorScheme.onSurface.withValues(alpha: 0.65)
            : theme.colorScheme.primary,
      ),
      itemBuilder: (context) => sortKeys
          .map(
            (key) => PopupMenuItem<String>(
              value: key,
              child: Row(
                children: [
                  if (key == sort)
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: AppSizes.p8),
                  Text(labelFor(key, l10n)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
