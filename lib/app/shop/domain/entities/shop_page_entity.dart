import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

/// Paginated catalog page (`data` + `meta` from Products API).
class ShopPageEntity extends Equatable {
  const ShopPageEntity({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<ProductEntity> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [items, total, page, limit, totalPages];
}

/// `GET /products/shop` — platform seller header + paginated products.
class PlatformShopPageEntity extends Equatable {
  const PlatformShopPageEntity({
    required this.seller,
    required this.page,
  });

  final ProductSellerEntity seller;
  final ShopPageEntity page;

  @override
  List<Object?> get props => [seller, page];
}
