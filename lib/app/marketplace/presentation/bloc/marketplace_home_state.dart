import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

class MarketplaceHomeState extends Equatable {
  const MarketplaceHomeState({
    this.loading = false,
    this.refreshing = false,
    this.error,
    this.categories = const [],
    this.recommended = const [],
    this.endingSoonAuctions = const [],
  });

  final bool loading;
  final bool refreshing;
  final String? error;
  final List<ProductCategoryEntity> categories;
  final List<ProductEntity> recommended;
  final List<AuctionDetailsEntity> endingSoonAuctions;

  MarketplaceHomeState copyWith({
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
    List<ProductCategoryEntity>? categories,
    List<ProductEntity>? recommended,
    List<AuctionDetailsEntity>? endingSoonAuctions,
  }) {
    return MarketplaceHomeState(
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      categories: categories ?? this.categories,
      recommended: recommended ?? this.recommended,
      endingSoonAuctions: endingSoonAuctions ?? this.endingSoonAuctions,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        refreshing,
        error,
        categories,
        recommended,
        endingSoonAuctions,
      ];
}
