import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AddPostCategoryPickerSheet {
  AddPostCategoryPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required List<CategoryEntity> categories,
    required CategoryEntity? selectedCategory,
    required ValueChanged<CategoryEntity> onSelected,
  }) {
    if (categories.isEmpty) return Future.value();

    final l10n = AppLocalizations.of(context)!;

    return GlassBottomSheetShell.show<void>(
      context,
      title: l10n.selectCategoryHint,
      scrollable: categories.length > 6,
      children: [
        for (final category in categories)
          GlassBottomSheetActionTile(
            icon: categoryIconForSlug(category.slug),
            label: category.name,
            subtitle: category.description,
            isSelected: selectedCategory?.id == category.id,
            showChevron: false,
            onTap: () {
              onSelected(category);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}
