import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

/// Query for `GET /products/purchased` (`PurchasedProductsQueryDto`).
class PurchasedProductsQueryParams extends Equatable {
  const PurchasedProductsQueryParams({
    this.page = 1,
    this.limit = 20,
    this.productCategoryId,
    this.sellerId,
    this.mediaType,
    this.search,
    this.minPriceCoins,
    this.maxPriceCoins,
    this.fulfillmentStatus,
    this.sortBy = 'lastPurchasedAt',
    this.sortOrder = 'desc',
  });

  final int page;
  final int limit;
  final String? productCategoryId;
  final String? sellerId;
  final ProductMediaType? mediaType;
  final String? search;
  final int? minPriceCoins;
  final int? maxPriceCoins;
  final ProductFulfillmentStatus? fulfillmentStatus;
  final String sortBy;
  final String sortOrder;

  PurchasedProductsQueryParams copyWith({
    int? page,
    int? limit,
    String? productCategoryId,
    String? sellerId,
    ProductMediaType? mediaType,
    String? search,
    int? minPriceCoins,
    int? maxPriceCoins,
    ProductFulfillmentStatus? fulfillmentStatus,
    String? sortBy,
    String? sortOrder,
    bool clearProductCategoryId = false,
    bool clearSellerId = false,
    bool clearMediaType = false,
    bool clearSearch = false,
    bool clearMinPriceCoins = false,
    bool clearMaxPriceCoins = false,
    bool clearFulfillmentStatus = false,
  }) {
    return PurchasedProductsQueryParams(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      productCategoryId: clearProductCategoryId
          ? null
          : (productCategoryId ?? this.productCategoryId),
      sellerId: clearSellerId ? null : (sellerId ?? this.sellerId),
      mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
      search: clearSearch ? null : (search ?? this.search),
      minPriceCoins:
          clearMinPriceCoins ? null : (minPriceCoins ?? this.minPriceCoins),
      maxPriceCoins:
          clearMaxPriceCoins ? null : (maxPriceCoins ?? this.maxPriceCoins),
      fulfillmentStatus: clearFulfillmentStatus
          ? null
          : (fulfillmentStatus ?? this.fulfillmentStatus),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  String? get fulfillmentStatusApi {
    if (fulfillmentStatus == null) return null;
    return switch (fulfillmentStatus!) {
      ProductFulfillmentStatus.none => 'NONE',
      ProductFulfillmentStatus.awaitingShipment => 'AWAITING_SHIPMENT',
      ProductFulfillmentStatus.shipped => 'SHIPPED',
      ProductFulfillmentStatus.delivered => 'DELIVERED',
      ProductFulfillmentStatus.accepted => 'ACCEPTED',
      ProductFulfillmentStatus.disputed => 'DISPUTED',
      ProductFulfillmentStatus.unknown => null,
    };
  }

  String? get mediaTypeApi {
    if (mediaType == null) return null;
    return switch (mediaType!) {
      ProductMediaType.image => 'IMAGE',
      ProductMediaType.video => 'VIDEO',
      ProductMediaType.carousel => 'CAROUSEL',
    };
  }

  Map<String, dynamic> toQueryParameters() {
    final q = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    final categoryId = productCategoryId?.trim();
    if (categoryId != null && categoryId.isNotEmpty) {
      q['productCategoryId'] = categoryId;
    }
    final seller = sellerId?.trim();
    if (seller != null && seller.isNotEmpty) {
      q['sellerId'] = seller;
    }
    final media = mediaTypeApi;
    if (media != null) q['mediaType'] = media;
    final s = search?.trim();
    if (s != null && s.isNotEmpty) q['search'] = s;
    if (minPriceCoins != null) q['minPriceCoins'] = minPriceCoins;
    if (maxPriceCoins != null) q['maxPriceCoins'] = maxPriceCoins;
    final fulfillment = fulfillmentStatusApi;
    if (fulfillment != null) q['fulfillmentStatus'] = fulfillment;
    return q;
  }

  @override
  List<Object?> get props => [
        page,
        limit,
        productCategoryId,
        sellerId,
        mediaType,
        search,
        minPriceCoins,
        maxPriceCoins,
        fulfillmentStatus,
        sortBy,
        sortOrder,
      ];
}
