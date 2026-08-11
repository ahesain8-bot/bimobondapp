import 'package:bimobondapp/app/shop/data/datasources/shop_cart_local_cache.dart';
import 'package:bimobondapp/app/shop/data/datasources/shop_remote_data_source.dart';
import 'package:bimobondapp/app/shop/domain/entities/cart_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/live_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_products_query.dart';
import 'package:bimobondapp/app/shop/domain/entities/shop_page_entity.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class ShopRepositoryImpl implements ShopRepository {
  ShopRepositoryImpl({
    required this.remoteDataSource,
    required this.cartLocalCache,
  });

  final ShopRemoteDataSource remoteDataSource;
  final ShopCartLocalCache cartLocalCache;

  Failure _map(Object e) => FailureMapper.from(e);

  @override
  Future<Either<Failure, ShopPageEntity>> browseProducts(
    BrowseProductsParams params,
  ) async {
    try {
      return Right(await remoteDataSource.browseProducts(params));
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> getProduct(String productId) async {
    try {
      return Right(await remoteDataSource.getProduct(productId));
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, PlatformShopPageEntity>> getPlatformShop(
    BrowseProductsParams params,
  ) async {
    try {
      return Right(await remoteDataSource.getPlatformShop(params));
    } catch (e) {
      final failure = _map(e);
      // Backend may not have PRODUCT_PLATFORM_SELLER_ID yet — use public catalog.
      if (!_isPlatformSellerNotConfigured(failure)) {
        return Left(failure);
      }
      try {
        final page = await remoteDataSource.browseProducts(params);
        return Right(
          PlatformShopPageEntity(
            seller: const ProductSellerEntity(id: '', username: 'shop'),
            page: page,
          ),
        );
      } catch (browseError) {
        return Left(_map(browseError));
      }
    }
  }

  bool _isPlatformSellerNotConfigured(Failure failure) {
    final message = failure.message.toLowerCase();
    return message.contains('product_platform_seller_id') ||
        message.contains('not configured in app settings');
  }

  @override
  Future<Either<Failure, List<ProductCategoryEntity>>>
      getProductCategories() async {
    try {
      return Right(await remoteDataSource.getProductCategories());
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, CartEntity>> getCart() async {
    try {
      final cart = await remoteDataSource.getCart();
      await cartLocalCache.saveCart(cart);
      return Right(cart);
    } catch (e) {
      final cached = cartLocalCache.loadCart();
      if (cached != null) {
        return Right(cached);
      }
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, CartEntity>> addCartItem({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    try {
      final cart = await remoteDataSource.addCartItem(
        productId: productId,
        variantId: variantId,
        quantity: quantity,
      );
      await cartLocalCache.saveCart(cart);
      return Right(cart);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, CartEntity>> updateCartItem({
    required String cartItemId,
    required int quantity,
  }) async {
    try {
      final cart = await remoteDataSource.updateCartItem(
        cartItemId: cartItemId,
        quantity: quantity,
      );
      await cartLocalCache.saveCart(cart);
      return Right(cart);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeCartItem(String cartItemId) async {
    try {
      await remoteDataSource.removeCartItem(cartItemId);
      final cart = await remoteDataSource.getCart();
      await cartLocalCache.saveCart(cart);
      return const Right(unit);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearCart() async {
    try {
      await remoteDataSource.clearCart();
      await cartLocalCache.clear();
      return const Right(unit);
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, CheckoutPreviewEntity>> previewCheckout({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod? paymentMethod,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
  }) async {
    try {
      return Right(
        await remoteDataSource.previewCheckout(
          items: items,
          paymentMethod: paymentMethod,
          giftPayments: giftPayments,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProductOrderEntity>> checkout({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod paymentMethod = ProductPaymentMethod.coins,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
    ShippingAddressInput? shippingAddress,
    String? couponCode,
    String? liveId,
    String? postId,
    String? idempotencyKey,
  }) async {
    try {
      return Right(
        await remoteDataSource.checkout(
          items: items,
          paymentMethod: paymentMethod,
          giftPayments: giftPayments,
          shippingAddress: shippingAddress,
          couponCode: couponCode,
          liveId: liveId,
          postId: postId,
          idempotencyKey: idempotencyKey,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, OrdersPageEntity>> getMyOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result =
          await remoteDataSource.getMyOrders(page: page, limit: limit);
      return Right(
        OrdersPageEntity(
          items: result.items,
          total: result.total,
          page: result.page,
          limit: result.limit,
          totalPages: result.totalPages,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, PurchasedProductsPageEntity>> getPurchasedProducts(
    PurchasedProductsQueryParams params,
  ) async {
    try {
      final result = await remoteDataSource.getPurchasedProducts(params);
      return Right(
        PurchasedProductsPageEntity(
          items: result.items,
          total: result.total,
          page: result.page,
          limit: result.limit,
          totalPages: result.totalPages,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, OrdersPageEntity>> getSalesOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result =
          await remoteDataSource.getSalesOrders(page: page, limit: limit);
      return Right(
        OrdersPageEntity(
          items: result.items,
          total: result.total,
          page: result.page,
          limit: result.limit,
          totalPages: result.totalPages,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProductOrderEntity>> getOrder(String orderId) async {
    try {
      return Right(await remoteDataSource.getOrder(orderId));
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProductOrderEntity>> shipOrder({
    required String orderId,
    String? trackingNumber,
    String? shippingNote,
  }) async {
    try {
      return Right(
        await remoteDataSource.shipOrder(
          orderId: orderId,
          trackingNumber: trackingNumber,
          shippingNote: shippingNote,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProductOrderEntity>> receiveOrder(
    String orderId,
  ) async {
    try {
      return Right(await remoteDataSource.receiveOrder(orderId));
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProductOrderEntity>> acceptOrder(
    String orderId,
  ) async {
    try {
      return Right(await remoteDataSource.acceptOrder(orderId));
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, ProductOrderEntity>> disputeOrder({
    required String orderId,
    String? note,
  }) async {
    try {
      return Right(
        await remoteDataSource.disputeOrder(orderId: orderId, note: note),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, List<LiveProductPinEntity>>> getLiveProducts(
    String liveId,
  ) async {
    try {
      return Right(await remoteDataSource.getLiveProducts(liveId));
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, LiveProductPinEntity>> addLiveProduct({
    required String liveId,
    required String productId,
  }) async {
    try {
      return Right(
        await remoteDataSource.addLiveProduct(
          liveId: liveId,
          productId: productId,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, LiveProductPinEntity>> pinLiveProduct({
    required String liveId,
    required String productId,
    required bool isPinned,
  }) async {
    try {
      return Right(
        await remoteDataSource.pinLiveProduct(
          liveId: liveId,
          productId: productId,
          isPinned: isPinned,
        ),
      );
    } catch (e) {
      return Left(_map(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeLiveProduct({
    required String liveId,
    required String productId,
  }) async {
    try {
      await remoteDataSource.removeLiveProduct(
        liveId: liveId,
        productId: productId,
      );
      return const Right(unit);
    } catch (e) {
      return Left(_map(e));
    }
  }

}
