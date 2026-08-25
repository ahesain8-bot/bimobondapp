import 'package:equatable/equatable.dart';

enum MarketplaceSortOption {
  popular,
  newest,
  priceLowHigh,
  priceHighLow,
  endingSoon,
}

enum MarketplaceListingType { buy, auction, all }

enum MarketplaceProductCondition { newItem, used, refurbished, any }

class MarketplaceFilters extends Equatable {
  const MarketplaceFilters({
    this.search,
    this.brand,
    this.minPriceCoins,
    this.maxPriceCoins,
    this.condition = MarketplaceProductCondition.any,
    this.listingType = MarketplaceListingType.all,
    this.inStockOnly = false,
    this.minRating,
    this.location,
  });

  final String? search;
  final String? brand;
  final int? minPriceCoins;
  final int? maxPriceCoins;
  final MarketplaceProductCondition condition;
  final MarketplaceListingType listingType;
  final bool inStockOnly;
  final double? minRating;
  final String? location;

  static const empty = MarketplaceFilters();

  bool get hasActiveFilters =>
      (search?.trim().isNotEmpty ?? false) ||
      (brand?.trim().isNotEmpty ?? false) ||
      minPriceCoins != null ||
      maxPriceCoins != null ||
      condition != MarketplaceProductCondition.any ||
      listingType != MarketplaceListingType.all ||
      inStockOnly ||
      minRating != null ||
      (location?.trim().isNotEmpty ?? false);

  MarketplaceFilters copyWith({
    String? search,
    bool clearSearch = false,
    String? brand,
    bool clearBrand = false,
    int? minPriceCoins,
    bool clearMinPrice = false,
    int? maxPriceCoins,
    bool clearMaxPrice = false,
    MarketplaceProductCondition? condition,
    MarketplaceListingType? listingType,
    bool? inStockOnly,
    double? minRating,
    bool clearMinRating = false,
    String? location,
    bool clearLocation = false,
  }) {
    return MarketplaceFilters(
      search: clearSearch ? null : (search ?? this.search),
      brand: clearBrand ? null : (brand ?? this.brand),
      minPriceCoins:
          clearMinPrice ? null : (minPriceCoins ?? this.minPriceCoins),
      maxPriceCoins:
          clearMaxPrice ? null : (maxPriceCoins ?? this.maxPriceCoins),
      condition: condition ?? this.condition,
      listingType: listingType ?? this.listingType,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      location: clearLocation ? null : (location ?? this.location),
    );
  }

  @override
  List<Object?> get props => [
        search,
        brand,
        minPriceCoins,
        maxPriceCoins,
        condition,
        listingType,
        inStockOnly,
        minRating,
        location,
      ];
}
