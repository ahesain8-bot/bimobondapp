import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_category_chip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_search_filters.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionsFilterSheet extends StatefulWidget {
  const AuctionsFilterSheet({
    required this.initialFilters,
    required this.categories,
    super.key,
  });

  final AuctionSearchFilters initialFilters;
  final List<CategoryEntity> categories;

  static Future<AuctionSearchFilters?> show(
    BuildContext context, {
    required AuctionSearchFilters initialFilters,
    required List<CategoryEntity> categories,
  }) {
    return showModalBottomSheet<AuctionSearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      builder: (context) => AuctionsFilterSheet(
        initialFilters: initialFilters,
        categories: categories,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipInactiveBg = isDark ? const Color(0xFF252525) : const Color(0xFFF3F4F6);
    final chipInactiveBorder = isDark
        ? Colors.white24
        : theme.dividerColor.withValues(alpha: 0.35);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppSizes.p8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p16,
                AppSizes.p8,
                AppSizes.p8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CustomText(
                      l10n.auctionsFiltersTitle,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(l10n.auctionsFiltersReset),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
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
                          selectedColor: theme.primaryColor,
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
                  ),
                  const SizedBox(height: AppSizes.p12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.auctionsFiltersMinPrice,
                            prefixIcon: const Icon(LucideIcons.dollarSign, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.p12),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.auctionsFiltersMaxPrice,
                            prefixIcon: const Icon(LucideIcons.dollarSign, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                            ),
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
                  ),
                  const SizedBox(height: AppSizes.p12),
                  Wrap(
                    spacing: AppSizes.p8,
                    runSpacing: AppSizes.p8,
                    children: AuctionTimeRemainingFilter.values.map((filter) {
                      final isSelected = _timeRemaining == filter;
                      return FilterChip(
                        label: Text(_timeRemainingLabel(l10n, filter)),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _timeRemaining = filter),
                        selectedColor: theme.primaryColor.withValues(alpha: 0.15),
                        checkmarkColor: theme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? theme.primaryColor
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
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
                    child: Text(l10n.auctionsFiltersApply),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
