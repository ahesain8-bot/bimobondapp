import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

class MarketplaceHomeState extends Equatable {
  const MarketplaceHomeState({
    this.loading = false,
    this.refreshing = false,
    this.error,
    this.categories = const [],
    this.recommended = const [],
  });

  final bool loading;
  final bool refreshing;
  final String? error;
  final List<ProductCategoryEntity> categories;
  final List<ProductEntity> recommended;

  MarketplaceHomeState copyWith({
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
    List<ProductCategoryEntity>? categories,
    List<ProductEntity>? recommended,
  }) {
    return MarketplaceHomeState(
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      categories: categories ?? this.categories,
      recommended: recommended ?? this.recommended,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        refreshing,
        error,
        categories,
        recommended,
      ];
}
