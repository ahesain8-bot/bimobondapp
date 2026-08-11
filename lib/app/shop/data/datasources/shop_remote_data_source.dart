import 'package:bimobondapp/app/shop/data/models/product_model.dart';
import 'package:bimobondapp/app/shop/data/models/shop_models.dart';
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/shop_page_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_products_query.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class ShopRemoteDataSource {
  Future<ShopPageEntity> browseProducts(BrowseProductsParams params);
  Future<PlatformShopPageEntity> getPlatformShop(BrowseProductsParams params);
  Future<ProductModel> getProduct(String productId);
  Future<List<ProductCategoryModel>> getProductCategories();

  Future<CartModel> getCart();
  Future<CartModel> addCartItem({
    required String productId,
    String? variantId,
    int quantity = 1,
  });
  Future<CartModel> updateCartItem({
    required String cartItemId,
    required int quantity,
  });
  Future<void> removeCartItem(String cartItemId);
  Future<void> clearCart();

  Future<CheckoutPreviewModel> previewCheckout({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod? paymentMethod,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
  });
  Future<ProductOrderModel> checkout({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod paymentMethod = ProductPaymentMethod.coins,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
    ShippingAddressInput? shippingAddress,
    String? couponCode,
    String? liveId,
    String? postId,
    String? idempotencyKey,
  });

  Future<
    ({
      List<ProductOrderModel> items,
      int total,
      int page,
      int limit,
      int totalPages,
    })
  >
  getMyOrders({int page = 1, int limit = 20});
  Future<
    ({
      List<ProductOrderModel> items,
      int total,
      int page,
      int limit,
      int totalPages,
    })
  >
  getSalesOrders({int page = 1, int limit = 20});
  Future<
    ({
      List<PurchasedProductModel> items,
      int total,
      int page,
      int limit,
      int totalPages,
    })
  >
  getPurchasedProducts(PurchasedProductsQueryParams params);
  Future<ProductOrderModel> getOrder(String orderId);
  Future<ProductOrderModel> shipOrder({
    required String orderId,
    String? trackingNumber,
    String? shippingNote,
  });
  Future<ProductOrderModel> receiveOrder(String orderId);
  Future<ProductOrderModel> acceptOrder(String orderId);
  Future<ProductOrderModel> disputeOrder({
    required String orderId,
    String? note,
  });

  Future<List<LiveProductPinModel>> getLiveProducts(String liveId);
  Future<LiveProductPinModel> addLiveProduct({
    required String liveId,
    required String productId,
  });
  Future<LiveProductPinModel> pinLiveProduct({
    required String liveId,
    required String productId,
    required bool isPinned,
  });
  Future<void> removeLiveProduct({
    required String liveId,
    required String productId,
  });
}

class ShopRemoteDataSourceImpl implements ShopRemoteDataSource {
  ShopRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders({bool required = false}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    if (required) {
      throw UnauthorizedException(message: 'Authentication required');
    }
    return {};
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
      return message?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  ShopPageEntity _parsePage(
    Map<String, dynamic> map, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final data = map['data'];
    final items = data is List
        ? data
              .whereType<Map>()
              .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
              .where((p) => p.id.isNotEmpty)
              .toList()
        : <ProductModel>[];
    final meta = map['meta'] is Map
        ? Map<String, dynamic>.from(map['meta'] as Map)
        : const <String, dynamic>{};
    final total = shopReadInt(meta['total'], items.length);
    final page = shopReadInt(meta['page'], fallbackPage);
    final limit = shopReadInt(meta['limit'], fallbackLimit);
    final totalPages = shopReadInt(
      meta['totalPages'] ?? meta['lastPage'],
      limit <= 0 ? 1 : ((total + limit - 1) ~/ limit).clamp(1, 1 << 20),
    );
    return ShopPageEntity(
      items: items,
      total: total,
      page: page,
      limit: limit,
      totalPages: totalPages,
    );
  }

  String _mediaTypeQuery(ProductMediaType type) {
    switch (type) {
      case ProductMediaType.video:
        return 'VIDEO';
      case ProductMediaType.carousel:
        return 'CAROUSEL';
      case ProductMediaType.image:
        return 'IMAGE';
    }
  }

  @override
  Future<ShopPageEntity> browseProducts(BrowseProductsParams params) async {
    try {
      final query = <String, dynamic>{
        'page': params.page,
        'limit': params.limit,
        'sortBy': params.sortBy,
        'sortOrder': params.sortOrder,
      };
      if (params.sellerId != null && params.sellerId!.isNotEmpty) {
        query['sellerId'] = params.sellerId;
      }
      if (params.productCategoryId != null &&
          params.productCategoryId!.isNotEmpty) {
        query['productCategoryId'] = params.productCategoryId;
      }
      if (params.mediaType != null) {
        query['mediaType'] = _mediaTypeQuery(params.mediaType!);
      }
      if (params.search != null && params.search!.trim().isNotEmpty) {
        query['search'] = params.search!.trim();
      }

      final response = await apiClient.dio.get(
        ApiConstants.products,
        queryParameters: query,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _parsePage(
          _asMap(response.data),
          fallbackPage: params.page,
          fallbackLimit: params.limit,
        );
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load products',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ProductModel> getProduct(String productId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.productById(productId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return ProductModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load product',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<PlatformShopPageEntity> getPlatformShop(
    BrowseProductsParams params,
  ) async {
    try {
      final query = <String, dynamic>{
        'page': params.page,
        'limit': params.limit,
        'sortBy': params.sortBy,
        'sortOrder': params.sortOrder,
      };
      if (params.productCategoryId != null &&
          params.productCategoryId!.isNotEmpty) {
        query['productCategoryId'] = params.productCategoryId;
      }
      if (params.mediaType != null) {
        query['mediaType'] = _mediaTypeQuery(params.mediaType!);
      }
      if (params.search != null && params.search!.trim().isNotEmpty) {
        query['search'] = params.search!.trim();
      }

      final response = await apiClient.dio.get(
        ApiConstants.productsShop,
        queryParameters: query,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final map = _asMap(response.data);
        final sellerRaw = map['seller'];
        final seller = sellerRaw is Map
            ? ProductSellerModel.fromJson(Map<String, dynamic>.from(sellerRaw))
            : const ProductSellerModel(id: '', username: 'shop');
        return PlatformShopPageEntity(
          seller: seller,
          page: _parsePage(
            map,
            fallbackPage: params.page,
            fallbackLimit: params.limit,
          ),
        );
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load platform shop',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<ProductCategoryModel>> getProductCategories() async {
    try {
      // `/product-categories` rejects sortBy/sortOrder query params (400).
      // Categories expose `order` (mapped to sortOrder in the model).
      final response = await apiClient.dio.get(
        ApiConstants.productCategories,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final body = response.data;
        final list = body is List
            ? body
            : body is Map
                ? (body['data'] is List
                    ? body['data'] as List
                    : body['items'] is List
                        ? body['items'] as List
                        : const [])
                : const [];
        final categories = list
            .whereType<Map>()
            .map(
              (e) =>
                  ProductCategoryModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .where((c) => c.id.isNotEmpty)
            .toList();
        categories.sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          if (byOrder != 0) return byOrder;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return categories;
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load product categories',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CartModel> getCart() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.productsCart,
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return CartModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load cart',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CartModel> addCartItem({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.productsCartItems,
        data: {
          'productId': productId,
          'quantity': quantity,
          if (variantId != null && variantId.isNotEmpty) 'variantId': variantId,
        },
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = _asMap(response.data);
        if (map.containsKey('items')) {
          return CartModel.fromJson(map);
        }
        // Some backends return the cart nested under `cart`.
        if (map['cart'] is Map) {
          return CartModel.fromJson(
            Map<String, dynamic>.from(map['cart'] as Map),
          );
        }
        return getCart();
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to add to cart',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CartModel> updateCartItem({
    required String cartItemId,
    required int quantity,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.productsCartItem(cartItemId),
        data: {'quantity': quantity},
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        final map = _asMap(response.data);
        if (map.containsKey('items')) {
          return CartModel.fromJson(map);
        }
        return getCart();
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to update cart item',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> removeCartItem(String cartItemId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.productsCartItem(cartItemId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to remove cart item',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> clearCart() async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.productsCart,
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to clear cart',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CheckoutPreviewModel> previewCheckout({
    required List<CheckoutItemInput> items,
    ProductPaymentMethod? paymentMethod,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
  }) async {
    try {
      final body = <String, dynamic>{
        'items': items.map((e) => e.toJson()).toList(),
        if (paymentMethod != null)
          'paymentMethod': shopPaymentMethodToApi(paymentMethod),
        if (giftPayments.isNotEmpty)
          'giftPayments': giftPayments.map((e) => e.toJson()).toList(),
      };
      final response = await apiClient.dio.post(
        ApiConstants.productsCheckoutPreview,
        data: body,
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CheckoutPreviewModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to preview checkout',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ProductOrderModel> checkout({
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
      final body = <String, dynamic>{
        'items': items.map((e) => e.toJson()).toList(),
        'paymentMethod': shopPaymentMethodToApi(paymentMethod),
        if (giftPayments.isNotEmpty)
          'giftPayments': giftPayments.map((e) => e.toJson()).toList(),
        if (shippingAddress != null)
          'shippingAddress': shippingAddress.toJson(),
        if (couponCode != null && couponCode.isNotEmpty)
          'couponCode': couponCode,
        if (liveId != null && liveId.isNotEmpty) 'liveId': liveId,
        if (postId != null && postId.isNotEmpty) 'postId': postId,
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'idempotencyKey': idempotencyKey,
      };
      final response = await apiClient.dio.post(
        ApiConstants.productsCheckout,
        data: body,
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ProductOrderModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Checkout failed',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  ({
    List<ProductOrderModel> items,
    int total,
    int page,
    int limit,
    int totalPages,
  })
  _parseOrders(Response response, {required int page, required int limit}) {
    final map = _asMap(response.data);
    final data = map['data'];
    final items = data is List
        ? data
              .whereType<Map>()
              .map(
                (e) => ProductOrderModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .where((o) => o.id.isNotEmpty)
              .toList()
        : <ProductOrderModel>[];
    final meta = map['meta'] is Map
        ? Map<String, dynamic>.from(map['meta'] as Map)
        : const <String, dynamic>{};
    final total = shopReadInt(meta['total'], items.length);
    final resolvedPage = shopReadInt(meta['page'], page);
    final resolvedLimit = shopReadInt(meta['limit'], limit);
    final totalPages = shopReadInt(
      meta['totalPages'] ?? meta['lastPage'],
      resolvedLimit <= 0
          ? 1
          : ((total + resolvedLimit - 1) ~/ resolvedLimit).clamp(1, 1 << 20),
    );
    return (
      items: items,
      total: total,
      page: resolvedPage,
      limit: resolvedLimit,
      totalPages: totalPages,
    );
  }

  @override
  Future<
    ({
      List<ProductOrderModel> items,
      int total,
      int page,
      int limit,
      int totalPages,
    })
  >
  getMyOrders({int page = 1, int limit = 20}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.productsOrdersMine,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return _parseOrders(response, page: page, limit: limit);
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load orders',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<
    ({
      List<ProductOrderModel> items,
      int total,
      int page,
      int limit,
      int totalPages,
    })
  >
  getSalesOrders({int page = 1, int limit = 20}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.productsOrdersSales,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return _parseOrders(response, page: page, limit: limit);
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load sales',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  ({
    List<PurchasedProductModel> items,
    int total,
    int page,
    int limit,
    int totalPages,
  })
  _parsePurchased(Response response, {required int page, required int limit}) {
    final map = _asMap(response.data);
    final rawList = map['data'] is List
        ? map['data'] as List
        : map['items'] is List
        ? map['items'] as List
        : response.data is List
        ? response.data as List
        : const [];
    final items = rawList
        .whereType<Map>()
        .map(
          (e) => PurchasedProductModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .where((p) => p.productId.isNotEmpty || p.id.isNotEmpty)
        .toList();
    final meta = map['meta'] is Map
        ? Map<String, dynamic>.from(map['meta'] as Map)
        : const <String, dynamic>{};
    final total = shopReadInt(meta['total'], items.length);
    final resolvedPage = shopReadInt(meta['page'], page);
    final resolvedLimit = shopReadInt(meta['limit'], limit);
    final totalPages = shopReadInt(
      meta['totalPages'] ?? meta['lastPage'],
      resolvedLimit <= 0
          ? 1
          : ((total + resolvedLimit - 1) ~/ resolvedLimit).clamp(1, 1 << 20),
    );
    return (
      items: items,
      total: total,
      page: resolvedPage,
      limit: resolvedLimit,
      totalPages: totalPages,
    );
  }

  @override
  Future<
    ({
      List<PurchasedProductModel> items,
      int total,
      int page,
      int limit,
      int totalPages,
    })
  >
  getPurchasedProducts(PurchasedProductsQueryParams params) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.productsPurchased,
        queryParameters: params.toQueryParameters(),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return _parsePurchased(
          response,
          page: params.page,
          limit: params.limit,
        );
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load purchased products',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ProductOrderModel> getOrder(String orderId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.productsOrderById(orderId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return ProductOrderModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load order',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ProductOrderModel> shipOrder({
    required String orderId,
    String? trackingNumber,
    String? shippingNote,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.productsOrderShip(orderId),
        data: {
          if (trackingNumber != null) 'trackingNumber': trackingNumber,
          if (shippingNote != null) 'shippingNote': shippingNote,
        },
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return ProductOrderModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to ship order',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ProductOrderModel> receiveOrder(String orderId) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.productsOrderReceive(orderId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return ProductOrderModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to confirm delivery',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ProductOrderModel> acceptOrder(String orderId) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.productsOrderAccept(orderId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return ProductOrderModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to accept order',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ProductOrderModel> disputeOrder({
    required String orderId,
    String? note,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.productsOrderDispute(orderId),
        data: {if (note != null) 'note': note},
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return ProductOrderModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to dispute order',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<LiveProductPinModel>> getLiveProducts(String liveId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.productsLiveItems(liveId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final map = _asMap(response.data);
        final data = map['data'] ?? response.data;
        final list = data is List ? data : const [];
        return list
            .whereType<Map>()
            .map(
              (e) => LiveProductPinModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .where((p) => p.productId.isNotEmpty)
            .toList();
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load live products',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<LiveProductPinModel> addLiveProduct({
    required String liveId,
    required String productId,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.productsLiveItems(liveId),
        data: {'productId': productId},
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return LiveProductPinModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to add live product',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<LiveProductPinModel> pinLiveProduct({
    required String liveId,
    required String productId,
    required bool isPinned,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.productsLiveItemPin(liveId, productId),
        data: {'isPinned': isPinned},
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return LiveProductPinModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to pin live product',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> removeLiveProduct({
    required String liveId,
    required String productId,
  }) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.productsLiveItem(liveId, productId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to remove live product',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
