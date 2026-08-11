import 'package:bimobondapp/app/shop/domain/entities/cart_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/live_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_products_query.dart';
import 'package:bimobondapp/app/shop/domain/entities/shop_page_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class BrowseProductsParams extends Equatable {
  const BrowseProductsParams({
    this.page = 1,
    this.limit = 20,
    this.sellerId,
    this.productCategoryId,
    this.mediaType,
    this.search,
    this.sortBy = 'sortOrder',
    this.sortOrder = 'asc',
  });

  final int page;
  final int limit;
  final String? sellerId;
  final String? productCategoryId;
  final ProductMediaType? mediaType;
  final String? search;
  final String sortBy;
  final String sortOrder;

  @override
  List<Object?> get props => [
        page,
        limit,
        sellerId,
        productCategoryId,
        mediaType,
        search,
        sortBy,
        sortOrder,
      ];
}

abstract class ShopRepository {
  // Catalog
  Future<Either<Failure, ShopPageEntity>> browseProducts(
    BrowseProductsParams params,
  );

  /// Platform shop tab — `GET /products/shop`.
  Future<Either<Failure, PlatformShopPageEntity>> getPlatformShop(
    BrowseProductsParams params,
  );
  Future<Either<Failure, ProductEntity>> getProduct(String productId);
  Future<Either<Failure, List<ProductCategoryEntity>>> getProductCategories();

  // Cart
  Future<Either<Failure, CartEntity>> getCart();
  Future<Either<Failure, CartEntity>> addCartItem({
    required String productId,
    String? variantId,
    int quantity = 1,
  });
  Future<Either<Failure, CartEntity>> updateCartItem({
    required String cartItemId,
    required int quantity,
  });
  Future<Either<Failure, Unit>> removeCartItem(String cartItemId);
  Future<Either<Failure, Unit>> clearCart();

  // Checkout
  Future<Either<Failure, CheckoutPreviewEntity>> previewCheckout({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod? paymentMethod,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
  });
  Future<Either<Failure, ProductOrderEntity>> checkout({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod paymentMethod = ProductPaymentMethod.coins,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
    ShippingAddressInput? shippingAddress,
    String? couponCode,
    String? liveId,
    String? postId,
    String? idempotencyKey,
  });

  // Orders
  Future<Either<Failure, OrdersPageEntity>> getMyOrders({
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, OrdersPageEntity>> getSalesOrders({
    int page = 1,
    int limit = 20,
  });

  /// Buyer inventory — `GET /products/purchased`.
  Future<Either<Failure, PurchasedProductsPageEntity>> getPurchasedProducts(
    PurchasedProductsQueryParams params,
  );
  Future<Either<Failure, ProductOrderEntity>> getOrder(String orderId);
  Future<Either<Failure, ProductOrderEntity>> shipOrder({
    required String orderId,
    String? trackingNumber,
    String? shippingNote,
  });
  Future<Either<Failure, ProductOrderEntity>> receiveOrder(String orderId);
  Future<Either<Failure, ProductOrderEntity>> acceptOrder(String orderId);
  Future<Either<Failure, ProductOrderEntity>> disputeOrder({
    required String orderId,
    String? note,
  });

  // Live shopping
  Future<Either<Failure, List<LiveProductPinEntity>>> getLiveProducts(
    String liveId,
  );
  Future<Either<Failure, LiveProductPinEntity>> addLiveProduct({
    required String liveId,
    required String productId,
  });
  Future<Either<Failure, LiveProductPinEntity>> pinLiveProduct({
    required String liveId,
    required String productId,
    required bool isPinned,
  });
  Future<Either<Failure, Unit>> removeLiveProduct({
    required String liveId,
    required String productId,
  });
}
