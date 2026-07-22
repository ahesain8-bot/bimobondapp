import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Themed category picker — matches add-post settings sheet (surface + cards).
class AddPostCategoryPickerSheet {
  AddPostCategoryPickerSheet._();

  static const double _sheetHeightFraction = 0.55;

  static Future<void> show(
    BuildContext context, {
    required List<CategoryEntity> categories,
    required CategoryEntity? selectedCategory,
    required ValueChanged<CategoryEntity> onSelected,
  }) {
    if (categories.isEmpty) return Future.value();

    final l10n = AppLocalizations.of(context)!;
    final height =
        MediaQuery.sizeOf(context).height * _sheetHeightFraction;

    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      lightSurface: true,
      showHandle: true,
      child: SizedBox(
        height: height,
        child: _CategoryPickerBody(
          title: l10n.selectCategoryHint,
          categories: categories,
          selectedCategory: selectedCategory,
          onSelected: onSelected,
        ),
      ),
    );
  }
}

class _CategoryPickerBody extends StatelessWidget {
  const _CategoryPickerBody({
    required this.title,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final String title;
  final List<CategoryEntity> categories;
  final CategoryEntity? selectedCategory;
  final ValueChanged<CategoryEntity> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2A2A2D)
        : const Color(0xFFF1F1F2);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    LucideIcons.x,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = selectedCategory?.id == category.id;
                    return _CategoryTile(
                      category: category,
                      selected: selected,
                      onTap: () {
                        onSelected(category);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CategoryEntity category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final subtitle = category.description?.trim();

    return Material(
      color: selected
          ? primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p12,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: 0.14)
                      : onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? primary.withValues(alpha: 0.35)
                        : onSurface.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  categoryIconForSlug(category.slug),
                  size: 20,
                  color: selected ? primary : onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(width: AppSizes.p16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      category.name,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: onSurface,
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(LucideIcons.check, size: 20, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
