import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_category_chip.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionsCategoryStrip extends StatelessWidget {
  const AuctionsCategoryStrip({
    required this.categories,
    required this.selectedCategorySlug,
    required this.chipInactiveBg,
    required this.inactiveBorder,
    required this.selectedColor,
    required this.onCategorySelected,
    super.key,
  });

  final List<CategoryEntity> categories;
  final String? selectedCategorySlug;
  final Color chipInactiveBg;
  final Color inactiveBorder;
  final Color selectedColor;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
        scrollDirection: Axis.horizontal,
        itemCount: 1 + categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.p8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return AuctionCategoryChip(
              label: l10n.auctionCategoryAll,
              icon: LucideIcons.layoutGrid,
              isSelected: selectedCategorySlug == null,
              selectedColor: selectedColor,
              inactiveBackground: chipInactiveBg,
              inactiveBorder: inactiveBorder,
              onTap: () => onCategorySelected(null),
            );
          }

          final category = categories[index - 1];
          return AuctionCategoryChip(
            label: category.name,
            icon: categoryIconForSlug(category.slug),
            isSelected: selectedCategorySlug == category.slug,
            selectedColor: selectedColor,
            inactiveBackground: chipInactiveBg,
            inactiveBorder: inactiveBorder,
            onTap: () => onCategorySelected(category.slug),
          );
        },
      ),
    );
  }
}
