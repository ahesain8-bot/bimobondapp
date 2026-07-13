import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchHistoryTile extends StatelessWidget {
  const SearchHistoryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final SearchHistoryEntity item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.clock, size: 20, color: muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: onSurface,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.x, size: 16, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
