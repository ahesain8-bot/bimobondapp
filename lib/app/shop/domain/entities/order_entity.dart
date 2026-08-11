import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:equatable/equatable.dart';

enum ProductOrderStatus { pending, paid, cancelled, refunded, unknown }

enum ProductFulfillmentStatus {
  none,
  awaitingShipment,
  shipped,
  delivered,
  accepted,
  disputed,
  unknown,
}

class OrderItemEntity extends Equatable {
  const OrderItemEntity({
    required this.id,
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPriceCoins,
    required this.lineTotalCoins,
    this.variantId,
    this.imageUrl,
  });

  final String id;
  final String productId;
  final String? variantId;
  final String title;
  final String? imageUrl;
  final int quantity;
  final int unitPriceCoins;
  final int lineTotalCoins;

  @override
  List<Object?> get props => [
        id,
        productId,
        variantId,
        title,
        imageUrl,
        quantity,
        unitPriceCoins,
        lineTotalCoins,
      ];
}

class OrderGiftPaymentEntity extends Equatable {
  const OrderGiftPaymentEntity({
    required this.giftId,
    required this.quantity,
    this.unitValueCoins,
  });

  final String giftId;
  final int quantity;
  final int? unitValueCoins;

  @override
  List<Object?> get props => [giftId, quantity, unitValueCoins];
}

class ProductOrderEntity extends Equatable {
  const ProductOrderEntity({
    required this.id,
    required this.orderNumber,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.paymentMethod,
    required this.subtotalCoins,
    required this.commissionCoins,
    required this.totalCoins,
    required this.fulfillmentStatus,
    required this.items,
    this.trackingNumber,
    this.shippingNote,
    this.liveId,
    this.postId,
    this.paidAt,
    this.shippedAt,
    this.deliveredAt,
    this.sellerAcceptedAt,
    this.buyerAcceptedAt,
    this.settledAt,
    this.shippingAddress,
    this.createdAt,
    this.giftPayments = const [],
  });

  final String id;
  final String orderNumber;
  final String buyerId;
  final String sellerId;
  final ProductOrderStatus status;
  final ProductPaymentMethod paymentMethod;
  final int subtotalCoins;
  final int commissionCoins;
  final int totalCoins;
  final ProductFulfillmentStatus fulfillmentStatus;
  final String? trackingNumber;
  final String? shippingNote;
  final String? liveId;
  final String? postId;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? sellerAcceptedAt;
  final DateTime? buyerAcceptedAt;
  final DateTime? settledAt;
  final Map<String, dynamic>? shippingAddress;
  final DateTime? createdAt;
  final List<OrderItemEntity> items;
  final List<OrderGiftPaymentEntity> giftPayments;

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        buyerId,
        sellerId,
        status,
        paymentMethod,
        subtotalCoins,
        commissionCoins,
        totalCoins,
        fulfillmentStatus,
        trackingNumber,
        shippingNote,
        liveId,
        postId,
        paidAt,
        shippedAt,
        deliveredAt,
        sellerAcceptedAt,
        buyerAcceptedAt,
        settledAt,
        shippingAddress,
        createdAt,
        items,
        giftPayments,
      ];
}

class OrdersPageEntity extends Equatable {
  const OrdersPageEntity({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<ProductOrderEntity> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [items, total, page, limit, totalPages];
}
