import 'package:bimobondapp/app/shop/data/models/product_model.dart';
import 'package:bimobondapp/app/shop/domain/entities/cart_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/live_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_product_entity.dart';

ProductPaymentMethod shopParsePaymentMethod(dynamic raw) {
  switch (raw?.toString().toUpperCase()) {
    case 'GIFTS':
      return ProductPaymentMethod.gifts;
    case 'MIXED':
      return ProductPaymentMethod.mixed;
    default:
      return ProductPaymentMethod.coins;
  }
}

String shopPaymentMethodToApi(ProductPaymentMethod method) {
  switch (method) {
    case ProductPaymentMethod.gifts:
      return 'GIFTS';
    case ProductPaymentMethod.mixed:
      return 'MIXED';
    case ProductPaymentMethod.coins:
      return 'COINS';
  }
}

ProductOrderStatus shopParseOrderStatus(dynamic raw) {
  switch (raw?.toString().toUpperCase()) {
    case 'PENDING':
      return ProductOrderStatus.pending;
    case 'PAID':
      return ProductOrderStatus.paid;
    case 'CANCELLED':
      return ProductOrderStatus.cancelled;
    case 'REFUNDED':
      return ProductOrderStatus.refunded;
    default:
      return ProductOrderStatus.unknown;
  }
}

ProductFulfillmentStatus shopParseFulfillmentStatus(dynamic raw) {
  switch (raw?.toString().toUpperCase()) {
    case 'NONE':
      return ProductFulfillmentStatus.none;
    case 'AWAITING_SHIPMENT':
      return ProductFulfillmentStatus.awaitingShipment;
    case 'SHIPPED':
      return ProductFulfillmentStatus.shipped;
    case 'DELIVERED':
      return ProductFulfillmentStatus.delivered;
    case 'ACCEPTED':
      return ProductFulfillmentStatus.accepted;
    case 'DISPUTED':
      return ProductFulfillmentStatus.disputed;
    default:
      return ProductFulfillmentStatus.unknown;
  }
}

class CartItemModel extends CartItemEntity {
  const CartItemModel({
    required super.id,
    required super.productId,
    required super.quantity,
    super.variantId,
    super.product,
    super.variant,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final productRaw = json['product'];
    final variantRaw = json['variant'];
    return CartItemModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['productId'] ??
              (productRaw is Map ? productRaw['id'] : null) ??
              '')
          .toString(),
      variantId: json['variantId']?.toString(),
      quantity: shopReadInt(json['quantity'], 1),
      product: productRaw is Map
          ? ProductModel.fromJson(Map<String, dynamic>.from(productRaw))
          : null,
      variant: variantRaw is Map
          ? ProductVariantModel.fromJson(Map<String, dynamic>.from(variantRaw))
          : null,
    );
  }
}

class CartModel extends CartEntity {
  const CartModel({
    required super.id,
    required super.userId,
    required super.items,
    super.updatedAt,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    return CartModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      updatedAt: shopReadDate(json['updatedAt']),
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => CartItemModel.fromJson(Map<String, dynamic>.from(e)))
              .where((i) => i.id.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

class CheckoutPreviewModel extends CheckoutPreviewEntity {
  const CheckoutPreviewModel({
    required super.lines,
    required super.subtotalCoins,
    required super.commissionCoins,
    required super.totalCoins,
    required super.giftValueCoins,
    required super.coinDueCoins,
    required super.commissionPercent,
    required super.sellerId,
  });

  factory CheckoutPreviewModel.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    return CheckoutPreviewModel(
      lines: linesRaw is List
          ? linesRaw.whereType<Map>().map((e) {
              final m = Map<String, dynamic>.from(e);
              return CheckoutLineEntity(
                productId: (m['productId'] ?? '').toString(),
                variantId: m['variantId']?.toString(),
                title: (m['title'] ?? '').toString(),
                imageUrl: shopResolveUrl(m['imageUrl']),
                quantity: shopReadInt(m['quantity'], 1),
                unitPriceCoins: shopReadInt(m['unitPriceCoins']),
                lineTotalCoins: shopReadInt(m['lineTotalCoins']),
              );
            }).toList()
          : const [],
      subtotalCoins: shopReadInt(json['subtotalCoins']),
      commissionCoins: shopReadInt(json['commissionCoins']),
      totalCoins: shopReadInt(json['totalCoins']),
      giftValueCoins: shopReadInt(json['giftValueCoins']),
      coinDueCoins: shopReadInt(json['coinDueCoins']),
      commissionPercent: shopReadInt(json['commissionPercent']),
      sellerId: (json['sellerId'] ?? '').toString(),
    );
  }
}

class OrderItemModel extends OrderItemEntity {
  const OrderItemModel({
    required super.id,
    required super.productId,
    required super.title,
    required super.quantity,
    required super.unitPriceCoins,
    required super.lineTotalCoins,
    super.variantId,
    super.imageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      variantId: json['variantId']?.toString(),
      title: (json['title'] ?? '').toString(),
      imageUrl: shopResolveUrl(json['imageUrl']),
      quantity: shopReadInt(json['quantity'], 1),
      unitPriceCoins: shopReadInt(json['unitPriceCoins']),
      lineTotalCoins: shopReadInt(json['lineTotalCoins']),
    );
  }
}

class ProductOrderModel extends ProductOrderEntity {
  const ProductOrderModel({
    required super.id,
    required super.orderNumber,
    required super.buyerId,
    required super.sellerId,
    required super.status,
    required super.paymentMethod,
    required super.subtotalCoins,
    required super.commissionCoins,
    required super.totalCoins,
    required super.fulfillmentStatus,
    required super.items,
    super.trackingNumber,
    super.shippingNote,
    super.liveId,
    super.postId,
    super.paidAt,
    super.shippedAt,
    super.deliveredAt,
    super.sellerAcceptedAt,
    super.buyerAcceptedAt,
    super.settledAt,
    super.shippingAddress,
    super.createdAt,
    super.giftPayments,
  });

  factory ProductOrderModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final giftsRaw = json['giftPayments'];
    final addressRaw = json['shippingAddressJson'] ?? json['shippingAddress'];
    return ProductOrderModel(
      id: (json['id'] ?? '').toString(),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      buyerId: (json['buyerId'] ?? '').toString(),
      sellerId: (json['sellerId'] ?? '').toString(),
      status: shopParseOrderStatus(json['status']),
      paymentMethod: shopParsePaymentMethod(json['paymentMethod']),
      subtotalCoins: shopReadInt(json['subtotalCoins']),
      commissionCoins: shopReadInt(json['commissionCoins']),
      totalCoins: shopReadInt(json['totalCoins']),
      fulfillmentStatus:
          shopParseFulfillmentStatus(json['fulfillmentStatus']),
      trackingNumber: json['trackingNumber']?.toString(),
      shippingNote: json['shippingNote']?.toString(),
      liveId: json['liveId']?.toString(),
      postId: json['postId']?.toString(),
      paidAt: shopReadDate(json['paidAt']),
      shippedAt: shopReadDate(json['shippedAt']),
      deliveredAt: shopReadDate(json['deliveredAt']),
      sellerAcceptedAt: shopReadDate(json['sellerAcceptedAt']),
      buyerAcceptedAt: shopReadDate(json['buyerAcceptedAt']),
      settledAt: shopReadDate(json['settledAt']),
      shippingAddress: addressRaw is Map
          ? Map<String, dynamic>.from(addressRaw)
          : null,
      createdAt: shopReadDate(json['createdAt']),
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      giftPayments: giftsRaw is List
          ? giftsRaw.whereType<Map>().map((e) {
              final m = Map<String, dynamic>.from(e);
              return OrderGiftPaymentEntity(
                giftId: (m['giftId'] ?? '').toString(),
                quantity: shopReadInt(m['quantity'], 1),
                unitValueCoins: m['unitValueCoins'] == null
                    ? null
                    : shopReadInt(m['unitValueCoins']),
              );
            }).toList()
          : const [],
    );
  }
}

class LiveProductPinModel extends LiveProductPinEntity {
  const LiveProductPinModel({
    required super.id,
    required super.liveId,
    required super.productId,
    required super.product,
    super.pinOrder,
    super.isPinned,
    super.pinnedAt,
  });

  factory LiveProductPinModel.fromJson(Map<String, dynamic> json) {
    final productRaw = json['product'];
    final product = productRaw is Map
        ? ProductModel.fromJson(Map<String, dynamic>.from(productRaw))
        : ProductModel(
            id: (json['productId'] ?? '').toString(),
            sellerId: '',
            title: '',
            priceCoins: 0,
          );
    return LiveProductPinModel(
      id: (json['id'] ?? '').toString(),
      liveId: (json['liveId'] ?? '').toString(),
      productId: (json['productId'] ?? product.id).toString(),
      product: product.copyWith(isLive: true),
      pinOrder: shopReadInt(json['pinOrder']),
      isPinned: shopReadBool(json['isPinned']),
      pinnedAt: shopReadDate(json['pinnedAt']),
    );
  }
}

class PurchasedProductModel extends PurchasedProductEntity {
  const PurchasedProductModel({
    required super.id,
    required super.productId,
    required super.title,
    required super.quantity,
    required super.priceCoins,
    super.imageUrl,
    super.variantId,
    super.orderId,
    super.status,
    super.fulfillmentStatus,
    super.purchasedAt,
  });

  factory PurchasedProductModel.fromJson(Map<String, dynamic> json) {
    final productRaw = json['product'];
    ProductModel? product;
    if (productRaw is Map) {
      product = ProductModel.fromJson(Map<String, dynamic>.from(productRaw));
    }

    // Prefer explicit / nested product ids. Do not parse the whole purchased
    // DTO as a Product — row `id` can differ from catalog `productId`.
    final productId = (json['productId'] ??
            json['product_id'] ??
            product?.id ??
            json['id'] ??
            '')
        .toString()
        .trim();
    final rowId = (json['id'] ?? productId).toString().trim();
    final title = (json['title'] ??
            json['name'] ??
            json['productTitle'] ??
            product?.title ??
            '')
        .toString();
    final imageUrl = shopResolveUrl(
          json['imageUrl'] ??
              json['thumbnailUrl'] ??
              json['coverUrl'] ??
              json['mediaUrl'],
        ) ??
        product?.displayImageUrl;
    final statusRaw = json['status'] ?? json['orderStatus'];
    final fulfillmentRaw =
        json['fulfillmentStatus'] ?? json['lastFulfillmentStatus'];
    final orderRaw = json['lastOrder'] ?? json['order'];
    String? orderId = (json['orderId'] ??
            json['productOrderId'] ??
            json['lastOrderId'] ??
            json['lastPaidOrderId'])
        ?.toString();
    if ((orderId == null || orderId.isEmpty) && orderRaw is Map) {
      orderId = (orderRaw['id'] ?? orderRaw['orderId'])?.toString();
    }

    return PurchasedProductModel(
      id: rowId.isNotEmpty ? rowId : productId,
      productId: productId,
      variantId: (json['variantId'] ?? json['productVariantId'])?.toString(),
      title: title.isNotEmpty ? title : productId,
      imageUrl: imageUrl,
      quantity: shopReadInt(
        json['totalQuantity'] ??
            json['quantity'] ??
            json['qty'] ??
            json['ownedQuantity'],
        1,
      ),
      priceCoins: shopReadInt(
        json['priceCoins'] ??
            json['unitPriceCoins'] ??
            json['totalCoins'] ??
            json['paidCoins'],
        product?.priceCoins ?? 0,
      ),
      orderId: orderId?.trim().isEmpty == true ? null : orderId?.trim(),
      status: statusRaw == null ? null : shopParseOrderStatus(statusRaw),
      fulfillmentStatus: fulfillmentRaw == null
          ? null
          : shopParseFulfillmentStatus(fulfillmentRaw),
      purchasedAt: shopReadDate(
        json['lastPurchasedAt'] ??
            json['purchasedAt'] ??
            json['paidAt'] ??
            json['createdAt'],
      ),
    );
  }
}
