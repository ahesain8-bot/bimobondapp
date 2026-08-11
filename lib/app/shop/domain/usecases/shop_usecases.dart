import 'package:bimobondapp/app/shop/domain/entities/cart_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/live_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_products_query.dart';
import 'package:bimobondapp/app/shop/domain/entities/shop_page_entity.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class BrowseProductsUseCase {
  BrowseProductsUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ShopPageEntity>> call(BrowseProductsParams params) =>
      _repository.browseProducts(params);
}

class GetProductUseCase {
  GetProductUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ProductEntity>> call(String productId) =>
      _repository.getProduct(productId);
}

class GetPlatformShopUseCase {
  GetPlatformShopUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, PlatformShopPageEntity>> call(
    BrowseProductsParams params,
  ) =>
      _repository.getPlatformShop(params);
}

class GetProductCategoriesUseCase {
  GetProductCategoriesUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, List<ProductCategoryEntity>>> call() =>
      _repository.getProductCategories();
}

class GetCartUseCase {
  GetCartUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, CartEntity>> call() => _repository.getCart();
}

class AddCartItemUseCase {
  AddCartItemUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, CartEntity>> call({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) =>
      _repository.addCartItem(
        productId: productId,
        variantId: variantId,
        quantity: quantity,
      );
}

class UpdateCartItemUseCase {
  UpdateCartItemUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, CartEntity>> call({
    required String cartItemId,
    required int quantity,
  }) =>
      _repository.updateCartItem(
        cartItemId: cartItemId,
        quantity: quantity,
      );
}

class RemoveCartItemUseCase {
  RemoveCartItemUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, Unit>> call(String cartItemId) =>
      _repository.removeCartItem(cartItemId);
}

class ClearCartUseCase {
  ClearCartUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.clearCart();
}

class PreviewCheckoutUseCase {
  PreviewCheckoutUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, CheckoutPreviewEntity>> call({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod? paymentMethod,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
  }) =>
      _repository.previewCheckout(
        items: items,
        paymentMethod: paymentMethod,
        giftPayments: giftPayments,
      );
}

class CheckoutUseCase {
  CheckoutUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ProductOrderEntity>> call({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod paymentMethod = ProductPaymentMethod.coins,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
    ShippingAddressInput? shippingAddress,
    String? couponCode,
    String? liveId,
    String? postId,
    String? idempotencyKey,
  }) =>
      _repository.checkout(
        items: items,
        paymentMethod: paymentMethod,
        giftPayments: giftPayments,
        shippingAddress: shippingAddress,
        couponCode: couponCode,
        liveId: liveId,
        postId: postId,
        idempotencyKey: idempotencyKey,
      );
}

class ShipOrderUseCase {
  ShipOrderUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ProductOrderEntity>> call({
    required String orderId,
    String? trackingNumber,
    String? shippingNote,
  }) =>
      _repository.shipOrder(
        orderId: orderId,
        trackingNumber: trackingNumber,
        shippingNote: shippingNote,
      );
}

class ReceiveOrderUseCase {
  ReceiveOrderUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ProductOrderEntity>> call(String orderId) =>
      _repository.receiveOrder(orderId);
}

class AcceptOrderUseCase {
  AcceptOrderUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ProductOrderEntity>> call(String orderId) =>
      _repository.acceptOrder(orderId);
}

class DisputeOrderUseCase {
  DisputeOrderUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ProductOrderEntity>> call({
    required String orderId,
    String? note,
  }) =>
      _repository.disputeOrder(orderId: orderId, note: note);
}

class AddLiveProductUseCase {
  AddLiveProductUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, LiveProductPinEntity>> call({
    required String liveId,
    required String productId,
  }) =>
      _repository.addLiveProduct(liveId: liveId, productId: productId);
}

class PinLiveProductUseCase {
  PinLiveProductUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, LiveProductPinEntity>> call({
    required String liveId,
    required String productId,
    required bool isPinned,
  }) =>
      _repository.pinLiveProduct(
        liveId: liveId,
        productId: productId,
        isPinned: isPinned,
      );
}

class RemoveLiveProductUseCase {
  RemoveLiveProductUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String liveId,
    required String productId,
  }) =>
      _repository.removeLiveProduct(liveId: liveId, productId: productId);
}

class GetMyOrdersUseCase {
  GetMyOrdersUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, OrdersPageEntity>> call({
    int page = 1,
    int limit = 20,
  }) =>
      _repository.getMyOrders(page: page, limit: limit);
}

class GetPurchasedProductsUseCase {
  GetPurchasedProductsUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, PurchasedProductsPageEntity>> call(
    PurchasedProductsQueryParams params,
  ) =>
      _repository.getPurchasedProducts(params);
}

class GetSalesOrdersUseCase {
  GetSalesOrdersUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, OrdersPageEntity>> call({
    int page = 1,
    int limit = 20,
  }) =>
      _repository.getSalesOrders(page: page, limit: limit);
}

class GetOrderUseCase {
  GetOrderUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, ProductOrderEntity>> call(String orderId) =>
      _repository.getOrder(orderId);
}

class GetLiveProductsUseCase {
  GetLiveProductsUseCase(this._repository);
  final ShopRepository _repository;

  Future<Either<Failure, List<LiveProductPinEntity>>> call(String liveId) =>
      _repository.getLiveProducts(liveId);
}

