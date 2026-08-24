import 'package:bimobondapp/app/marketplace/domain/entities/marketplace_filters.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

Future<MarketplaceFilters?> showMarketplaceFilterSheet({
  required BuildContext context,
  required MarketplaceFilters initial,
}) {
  return showModalBottomSheet<MarketplaceFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FilterSheet(initial: initial),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final MarketplaceFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MarketplaceFilters _filters;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
    if (_filters.minPriceCoins != null) {
      _minController.text = '${_filters.minPriceCoins}';
    }
    if (_filters.maxPriceCoins != null) {
      _maxController.text = '${_filters.maxPriceCoins}';
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MarketplaceTheme.radiusXl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.mutedText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.marketplaceFilters,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.marketplaceFilterPrice, style: _label(theme)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: l10n.marketplaceMin),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: l10n.marketplaceMax),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.marketplaceFilterListingType, style: _label(theme)),
              Wrap(
                spacing: 8,
                children: MarketplaceListingType.values.map((type) {
                  final selected = _filters.listingType == type;
                  final label = switch (type) {
                    MarketplaceListingType.all => l10n.shopAllCategories,
                    MarketplaceListingType.buy => l10n.shopBuyNow,
                    MarketplaceListingType.auction =>
                      l10n.marketplaceAuctionLabel,
                  };
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(
                      () => _filters = _filters.copyWith(listingType: type),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.marketplaceInStockOnly),
                value: _filters.inStockOnly,
                onChanged: (v) =>
                    setState(() => _filters = _filters.copyWith(inStockOnly: v)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, MarketplaceFilters.empty),
                      child: Text(l10n.marketplaceClearFilters),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final min = int.tryParse(_minController.text.trim());
                        final max = int.tryParse(_maxController.text.trim());
                        Navigator.pop(
                          context,
                          _filters.copyWith(
                            minPriceCoins: min,
                            clearMinPrice: min == null,
                            maxPriceCoins: max,
                            clearMaxPrice: max == null,
                          ),
                        );
                      },
                      child: Text(l10n.marketplaceApplyFilters),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _label(MarketplaceTheme theme) => TextStyle(
        color: theme.onSurface,
        fontWeight: FontWeight.w700,
      );
}

Future<MarketplaceSortOption?> showMarketplaceSortSheet({
  required BuildContext context,
  required MarketplaceSortOption initial,
}) {
  return showModalBottomSheet<MarketplaceSortOption>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SortSheet(initial: initial),
  );
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.initial});

  final MarketplaceSortOption initial;

  String _label(AppLocalizations l10n, MarketplaceSortOption option) {
    return switch (option) {
      MarketplaceSortOption.popular => l10n.marketplaceSortPopular,
      MarketplaceSortOption.newest => l10n.shopSortNewest,
      MarketplaceSortOption.priceLowHigh => l10n.shopSortPriceLow,
      MarketplaceSortOption.priceHighLow => l10n.shopSortPriceHigh,
      MarketplaceSortOption.endingSoon => l10n.marketplaceSortEndingSoon,
    };
  }

  static const _sortOptions = [
    MarketplaceSortOption.popular,
    MarketplaceSortOption.newest,
    MarketplaceSortOption.priceLowHigh,
    MarketplaceSortOption.priceHighLow,
    MarketplaceSortOption.endingSoon,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MarketplaceTheme.radiusXl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.shopSort,
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ..._SortSheet._sortOptions.map((option) {
            return RadioListTile<MarketplaceSortOption>(
              value: option,
              groupValue: initial,
              title: Text(_label(l10n, option)),
              onChanged: (v) => Navigator.pop(context, v),
            );
          }),
        ],
      ),
    );
  }
}
