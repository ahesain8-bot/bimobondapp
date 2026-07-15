import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CommentSortMenu extends StatelessWidget {
  const CommentSortMenu({
    required this.sort,
    required this.onSortChanged,
    this.iconOnly = false,
    super.key,
  });

  static const sortKeys = ['newest', 'oldest', 'top'];

  final String sort;
  final ValueChanged<String> onSortChanged;
  final bool iconOnly;

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

  Future<void> _openMenu(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final button = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(button.left, button.bottom, button.width, 0),
        Offset.zero & overlay.size,
      ),
      color: theme.colorScheme.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      items: [
        for (final key in sortKeys)
          PopupMenuItem<String>(
            value: key,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labelFor(key, l10n),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: key == sort
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (key == sort)
                  Icon(
                    LucideIcons.check,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDefaultSort = sort == 'newest';
    final muted = onSurface.withValues(alpha: 0.55);

    return Builder(
      builder: (triggerContext) {
        if (iconOnly) {
          return IconButton(
            tooltip: labelFor(sort, l10n),
            onPressed: () => _openMenu(triggerContext),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              LucideIcons.slidersHorizontal,
              size: 20,
              color: isDefaultSort ? muted : onSurface,
            ),
          );
        }

        return GestureDetector(
          onTap: () => _openMenu(triggerContext),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.slidersHorizontal,
                  size: 16,
                  color: isDefaultSort ? muted : onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  labelFor(sort, l10n),
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 13,
                    fontWeight: isDefaultSort
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, size: 16, color: muted),
              ],
            ),
          ),
        );
      },
    );
  }
}
