import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_category_chip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_search_filters.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionsFilterSheet extends StatefulWidget {
  const AuctionsFilterSheet({
    required this.initialFilters,
    required this.categories,
    required this.scrollController,
    super.key,
  });

  final AuctionSearchFilters initialFilters;
  final List<CategoryEntity> categories;
  final ScrollController scrollController;

  static Future<AuctionSearchFilters?> show(
    BuildContext context, {
    required AuctionSearchFilters initialFilters,
    required List<CategoryEntity> categories,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return GlassBottomSheet.showDraggable<AuctionSearchFilters>(
      context,
      title: l10n.auctionsFiltersTitle,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      adaptTheme: true,
      builder: (context, scrollController) => AuctionsFilterSheet(
        initialFilters: initialFilters,
        categories: categories,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<AuctionsFilterSheet> createState() => _AuctionsFilterSheetState();
}

class _AuctionsFilterSheetState extends State<AuctionsFilterSheet> {
  late Set<String> _selectedCategoryIds;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late AuctionTimeRemainingFilter _timeRemaining;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = Set<String>.from(widget.initialFilters.categoryIds);
    _minPriceController = TextEditingController(
      text: _formatPrice(widget.initialFilters.minPriceUsd),
    );
    _maxPriceController = TextEditingController(
      text: _formatPrice(widget.initialFilters.maxPriceUsd),
    );
    _timeRemaining = widget.initialFilters.timeRemaining;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  String _formatPrice(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }

  double? _parsePrice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', ''));
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  void _reset() {
    setState(() {
      _selectedCategoryIds.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _timeRemaining = AuctionTimeRemainingFilter.any;
    });
  }

  void _apply() {
    final minPrice = _parsePrice(_minPriceController.text);
    final maxPrice = _parsePrice(_maxPriceController.text);

    if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.auctionsFiltersInvalidPriceRange)),
      );
      return;
    }

    Navigator.pop(
      context,
      AuctionSearchFilters(
        categoryIds: _selectedCategoryIds,
        minPriceUsd: minPrice,
        maxPriceUsd: maxPrice,
        timeRemaining: _timeRemaining,
        liveStatus: widget.initialFilters.liveStatus,
      ),
    );
  }

  String _timeRemainingLabel(AppLocalizations l10n, AuctionTimeRemainingFilter filter) {
    switch (filter) {
      case AuctionTimeRemainingFilter.any:
        return l10n.auctionsTimeRemainingAny;
      case AuctionTimeRemainingFilter.endingWithin1Hour:
        return l10n.auctionsTimeRemaining1Hour;
      case AuctionTimeRemainingFilter.endingWithin6Hours:
        return l10n.auctionsTimeRemaining6Hours;
      case AuctionTimeRemainingFilter.endingWithin24Hours:
        return l10n.auctionsTimeRemaining24Hours;
      case AuctionTimeRemainingFilter.endingWithin7Days:
        return l10n.auctionsTimeRemaining7Days;
      case AuctionTimeRemainingFilter.endingWithin30Days:
        return l10n.auctionsTimeRemaining30Days;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const chipInactiveBg = Color(0x1FFFFFFF);
    const chipInactiveBorder = Color(0x33FFFFFF);
    const labelColor = Colors.white;
    const mutedColor = Color(0xA3FFFFFF);

    InputDecoration priceDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: mutedColor),
        prefixIcon: Icon(
          LucideIcons.dollarSign,
          size: 18,
          color: Colors.white.withValues(alpha: 0.65),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p12,
          vertical: AppSizes.p12,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            0,
            AppSizes.p8,
            AppSizes.p8,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _reset,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(l10n.auctionsFiltersReset),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              0,
              AppSizes.p16,
              AppSizes.p16,
            ),
            children: [
              CustomText(
                l10n.auctionsFiltersCategories,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
              const SizedBox(height: AppSizes.p12),
              Wrap(
                spacing: AppSizes.p8,
                runSpacing: AppSizes.p8,
                children: [
                  for (final category in widget.categories)
                    AuctionCategoryChip(
                      label: category.name,
                      icon: categoryIconForSlug(category.slug),
                      isSelected: _selectedCategoryIds.contains(category.id),
                      selectedColor: const Color(0xFF2ECC71),
                      inactiveBackground: chipInactiveBg,
                      inactiveBorder: chipInactiveBorder,
                      onTap: () => _toggleCategory(category.id),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.p24),
              CustomText(
                l10n.auctionsFiltersPriceRange,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
              const SizedBox(height: AppSizes.p12),
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassSurface(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      child: TextField(
                        controller: _minPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: const TextStyle(color: labelColor),
                        cursorColor: Colors.white,
                        decoration: priceDecoration(l10n.auctionsFiltersMinPrice),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: LiquidGlassSurface(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: const TextStyle(color: labelColor),
                        cursorColor: Colors.white,
                        decoration: priceDecoration(l10n.auctionsFiltersMaxPrice),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p24),
              CustomText(
                l10n.auctionsFiltersTimeRemaining,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
              const SizedBox(height: AppSizes.p12),
              Wrap(
                spacing: AppSizes.p8,
                runSpacing: AppSizes.p8,
                children: AuctionTimeRemainingFilter.values.map((filter) {
                  final isSelected = _timeRemaining == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _timeRemaining = filter),
                    child: LiquidGlassSurface(
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : chipInactiveBg,
                      borderColor: isSelected
                          ? Colors.white.withValues(alpha: 0.55)
                          : chipInactiveBorder,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p12,
                        vertical: AppSizes.p10,
                      ),
                      child: Text(
                        _timeRemainingLabel(l10n, filter),
                        style: TextStyle(
                          color: isSelected ? Colors.white : mutedColor,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p8,
              AppSizes.p16,
              AppSizes.p16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l10n.auctionsFiltersApply),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
