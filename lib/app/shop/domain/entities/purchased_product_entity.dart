import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:equatable/equatable.dart';

/// One row from `GET /products/purchased` (buyer inventory / purchased catalog).
class PurchasedProductEntity extends Equatable {
  const PurchasedProductEntity({
    required this.id,
    required this.productId,
    required this.title,
    required this.quantity,
    required this.priceCoins,
    this.imageUrl,
    this.variantId,
    this.orderId,
    this.status,
    this.fulfillmentStatus,
    this.purchasedAt,
  });

  final String id;
  final String productId;
  final String? variantId;
  final String title;
  final String? imageUrl;
  /// Aggregated owned quantity (`totalQuantity` from API when present).
  final int quantity;
  final int priceCoins;
  final String? orderId;
  final ProductOrderStatus? status;
  /// Most recent paid order fulfillment status.
  final ProductFulfillmentStatus? fulfillmentStatus;
  final DateTime? purchasedAt;

  @override
  List<Object?> get props => [
        id,
        productId,
        variantId,
        title,
        imageUrl,
        quantity,
        priceCoins,
        orderId,
        status,
        fulfillmentStatus,
        purchasedAt,
      ];
}

class PurchasedProductsPageEntity extends Equatable {
  const PurchasedProductsPageEntity({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<PurchasedProductEntity> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [items, total, page, limit, totalPages];
}
