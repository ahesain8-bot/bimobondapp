import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final theme = Theme.of(context);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.p16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p16,
                AppSizes.p16,
                AppSizes.p8,
              ),
              child: CustomText(
                l10n.selectCategoryHint,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            for (final category in categories)
              ListTile(
                leading: Icon(
                  categoryIconForSlug(category.slug),
                  color: selectedCategory?.id == category.id
                      ? theme.colorScheme.primary
                      : null,
                ),
                title: Text(category.name),
                subtitle: category.description != null &&
                        category.description!.isNotEmpty
                    ? Text(
                        category.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: selectedCategory?.id == category.id
                    ? Icon(LucideIcons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  onSelected(category);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: AppSizes.p20),
          ],
        ),
      ),
    );
  }
}
