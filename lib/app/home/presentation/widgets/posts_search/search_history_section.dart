import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_history_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_list_skeleton.dart';
import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchHistorySection extends StatelessWidget {
  const SearchHistorySection({
    required this.items,
    required this.expanded,
    required this.isLoading,
    required this.onTapItem,
    required this.onDeleteItem,
    required this.onClearAll,
    required this.onToggleExpanded,
    this.collapsedCount = 3,
    super.key,
  });

  final List<SearchHistoryEntity> items;
  final bool expanded;
  final bool isLoading;
  final ValueChanged<SearchHistoryEntity> onTapItem;
  final ValueChanged<SearchHistoryEntity> onDeleteItem;
  final VoidCallback onClearAll;
  final VoidCallback onToggleExpanded;
  final int collapsedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    if (isLoading && items.isEmpty) {
      return SearchListSkeleton(itemCount: collapsedCount);
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = expanded || items.length <= collapsedCount
        ? items
        : items.take(collapsedCount).toList();
    final canToggle = items.length > collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p8,
            AppSizes.p8,
            AppSizes.p4,
          ),
          child: Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(l10n.searchHistoryClear),
              ),
            ],
          ),
        ),
        for (final item in visible)
          SearchHistoryTile(
            item: item,
            onTap: () => onTapItem(item),
            onDelete: () => onDeleteItem(item),
          ),
        if (canToggle)
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    expanded ? l10n.searchSeeLess : l10n.searchSeeAll,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: muted,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
