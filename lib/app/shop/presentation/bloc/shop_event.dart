import 'package:equatable/equatable.dart';

abstract class ShopEvent extends Equatable {
  const ShopEvent();

  @override
  List<Object?> get props => [];
}

class ShopStarted extends ShopEvent {
  const ShopStarted();
}

class ShopRefreshed extends ShopEvent {
  const ShopRefreshed();
}

class ShopCategorySelected extends ShopEvent {
  const ShopCategorySelected(this.categoryId);

  /// `null` means all categories.
  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

class ShopSearchChanged extends ShopEvent {
  const ShopSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ShopSortChanged extends ShopEvent {
  const ShopSortChanged({
    required this.sortBy,
    required this.sortOrder,
  });

  final String sortBy;
  final String sortOrder;

  @override
  List<Object?> get props => [sortBy, sortOrder];
}

class ShopLoadMore extends ShopEvent {
  const ShopLoadMore();
}

class ShopAddToCart extends ShopEvent {
  const ShopAddToCart({
    required this.productId,
    this.variantId,
    this.quantity = 1,
  });

  final String productId;
  final String? variantId;
  final int quantity;

  @override
  List<Object?> get props => [productId, variantId, quantity];
}

class ShopLoadCart extends ShopEvent {
  const ShopLoadCart();
}

class ShopLoadProduct extends ShopEvent {
  const ShopLoadProduct(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

class ShopLoadOrders extends ShopEvent {
  const ShopLoadOrders({this.page = 1});

  final int page;

  @override
  List<Object?> get props => [page];
}
