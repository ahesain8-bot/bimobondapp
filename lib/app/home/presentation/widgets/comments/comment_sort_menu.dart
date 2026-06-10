import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_dropdown.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
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

  Future<void> _openDropdown(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final selected = await LiquidGlassDropdownMenu.show<String>(
      context: context,
      anchor: anchor,
      alignTrailing: true,
      items: [
        for (final key in sortKeys)
          LiquidGlassDropdownItem(
            value: key,
            label: labelFor(key, l10n),
            isSelected: key == sort,
          ),
      ],
    );

    if (selected != null && selected != sort) {
      onSortChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDefaultSort = sort == 'newest';

    return Builder(
      builder: (triggerContext) {
        return GestureDetector(
          onTap: () => _openDropdown(triggerContext),
          behavior: HitTestBehavior.opaque,
          child: LiquidGlassSurface(
            borderRadius: BorderRadius.circular(20),
            blurSigma: 16,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p10,
              vertical: AppSizes.p6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.slidersHorizontal,
                  size: 16,
                  color: isDefaultSort
                      ? Colors.white.withValues(alpha: 0.65)
                      : Colors.white,
                ),
                const SizedBox(width: AppSizes.p6),
                Text(
                  labelFor(sort, l10n),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                        isDefaultSort ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSizes.p4),
                Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
