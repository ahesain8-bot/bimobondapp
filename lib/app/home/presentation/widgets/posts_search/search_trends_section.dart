import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_list_skeleton.dart';
import 'package:bimobondapp/app/search/domain/entities/search_trend_entity.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchTrendsSection extends StatelessWidget {
  const SearchTrendsSection({
    required this.items,
    required this.expanded,
    required this.isLoading,
    required this.onTapItem,
    required this.onToggleExpanded,
    this.collapsedCount = 5,
    super.key,
  });

  final List<SearchTrendEntity> items;
  final bool expanded;
  final bool isLoading;
  final ValueChanged<SearchTrendEntity> onTapItem;
  final VoidCallback onToggleExpanded;
  final int collapsedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    if (isLoading && items.isEmpty) {
      return SearchListSkeleton(
        itemCount: collapsedCount,
        showHeader: true,
        headerWidth: 110,
      );
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
            AppSizes.p16,
            AppSizes.p16,
            AppSizes.p8,
          ),
          child: Text(
            l10n.searchYouMayLike,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        for (var i = 0; i < visible.length; i++)
          SearchTrendTile(
            item: visible[i],
            index: i,
            onTap: () => onTapItem(visible[i]),
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

class SearchTrendTile extends StatelessWidget {
  const SearchTrendTile({
    required this.item,
    required this.index,
    required this.onTap,
    super.key,
  });

  final SearchTrendEntity item;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isHot = index < 3;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(
              isHot ? LucideIcons.flame : LucideIcons.trendingUp,
              size: 20,
              color: isHot
                  ? AppTheme.primaryColor
                  : onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: onSurface,
                ),
              ),
            ),
            if (isHot)
              Icon(
                LucideIcons.arrowUp,
                size: 14,
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
              ),
          ],
        ),
      ),
    );
  }
}
