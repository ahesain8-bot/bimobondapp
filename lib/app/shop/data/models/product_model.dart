import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

int shopReadInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool shopReadBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return fallback;
}

DateTime? shopReadDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String? shopResolveUrl(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return MediaUtils.resolveAbsoluteUrl(raw);
}

ProductMediaType shopParseMediaType(dynamic raw) {
  switch (raw?.toString().toUpperCase()) {
    case 'VIDEO':
      return ProductMediaType.video;
    case 'CAROUSEL':
      return ProductMediaType.carousel;
    default:
      return ProductMediaType.image;
  }
}

ProductStatus shopParseStatus(dynamic raw) {
  switch (raw?.toString().toUpperCase()) {
    case 'DRAFT':
      return ProductStatus.draft;
    case 'ACTIVE':
      return ProductStatus.active;
    case 'PAUSED':
      return ProductStatus.paused;
    case 'ARCHIVED':
      return ProductStatus.archived;
    default:
      return ProductStatus.unknown;
  }
}

class ProductCategoryModel extends ProductCategoryEntity {
  const ProductCategoryModel({
    required super.id,
    required super.name,
    required super.slug,
    super.iconUrl,
    super.sortOrder,
    super.isActive,
  });

  factory ProductCategoryModel.fromJson(Map<String, dynamic> json) {
    return ProductCategoryModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      iconUrl: shopResolveUrl(json['iconUrl']),
      sortOrder: shopReadInt(
        json['sortOrder'] ?? json['order'] ?? json['displayOrder'],
      ),
      isActive: shopReadBool(json['isActive'], true),
    );
  }
}

class ProductSellerModel extends ProductSellerEntity {
  const ProductSellerModel({
    required super.id,
    required super.username,
    super.avatarUrl,
    super.showShopOnProfile,
    super.verificationBadge,
  });

  factory ProductSellerModel.fromJson(Map<String, dynamic> json) {
    return ProductSellerModel(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? json['name'] ?? '').toString(),
      avatarUrl: shopResolveUrl(json['avatarUrl']),
      showShopOnProfile: json.containsKey('showShopOnProfile')
          ? shopReadBool(json['showShopOnProfile'])
          : null,
      verificationBadge: json['verificationBadge']?.toString(),
    );
  }
}

class ProductMediaModel extends ProductMediaEntity {
  const ProductMediaModel({
    required super.id,
    required super.url,
    required super.mediaType,
    super.hlsUrl,
    super.sortOrder,
    super.width,
    super.height,
    super.duration,
  });

  factory ProductMediaModel.fromJson(Map<String, dynamic> json) {
    return ProductMediaModel(
      id: (json['id'] ?? '').toString(),
      url: shopResolveUrl(json['url']) ?? '',
      mediaType: shopParseMediaType(json['mediaType']),
      hlsUrl: shopResolveUrl(json['hlsUrl']),
      sortOrder: shopReadInt(json['sortOrder']),
      width: json['width'] == null ? null : shopReadInt(json['width']),
      height: json['height'] == null ? null : shopReadInt(json['height']),
      duration: json['duration'] == null ? null : shopReadInt(json['duration']),
    );
  }
}

class ProductVariantModel extends ProductVariantEntity {
  const ProductVariantModel({
    required super.id,
    required super.name,
    required super.priceCoins,
    super.sku,
    super.stockQuantity,
    super.imageUrl,
    super.attributes,
    super.sortOrder,
    super.isActive,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'];
    return ProductVariantModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      priceCoins: shopReadInt(json['priceCoins']),
      sku: json['sku']?.toString(),
      stockQuantity: shopReadInt(json['stockQuantity']),
      imageUrl: shopResolveUrl(json['imageUrl']),
      attributes: attrs is Map
          ? Map<String, dynamic>.from(attrs)
          : const <String, dynamic>{},
      sortOrder: shopReadInt(json['sortOrder']),
      isActive: shopReadBool(json['isActive'], true),
    );
  }
}

class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.sellerId,
    required super.title,
    required super.priceCoins,
    super.description,
    super.slug,
    super.status,
    super.mediaType,
    super.coverImageUrl,
    super.thumbnailUrl,
    super.videoUrl,
    super.hlsUrl,
    super.duration,
    super.productCategoryId,
    super.compareAtCoins,
    super.currencyCode,
    super.stockQuantity,
    super.trackInventory,
    super.allowCoinPayment,
    super.allowGiftPayment,
    super.sortOrder,
    super.publishedAt,
    super.sourcePostId,
    super.createdAt,
    super.updatedAt,
    super.seller,
    super.productCategory,
    super.media,
    super.variants,
    super.isFavorite,
    super.isLive,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final sellerRaw = json['seller'];
    final categoryRaw = json['productCategory'];
    final mediaRaw = json['media'];
    final variantsRaw = json['variants'];

    final compare = json['compareAtCoins'];
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      sellerId:
          (json['sellerId'] ??
                  (sellerRaw is Map ? sellerRaw['id'] : null) ??
                  '')
              .toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      slug: json['slug']?.toString(),
      status: shopParseStatus(json['status']),
      mediaType: shopParseMediaType(json['mediaType']),
      coverImageUrl: shopResolveUrl(json['coverImageUrl']),
      thumbnailUrl: shopResolveUrl(json['thumbnailUrl']),
      videoUrl: shopResolveUrl(json['videoUrl']),
      hlsUrl: shopResolveUrl(json['hlsUrl']),
      duration: json['duration'] == null ? null : shopReadInt(json['duration']),
      productCategoryId:
          (json['productCategoryId'] ??
                  (categoryRaw is Map ? categoryRaw['id'] : null))
              ?.toString(),
      priceCoins: shopReadInt(json['priceCoins']),
      compareAtCoins: compare == null ? null : shopReadInt(compare),
      currencyCode: (json['currencyCode'] ?? 'USD').toString(),
      stockQuantity: shopReadInt(json['stockQuantity']),
      trackInventory: shopReadBool(json['trackInventory'], true),
      allowCoinPayment: shopReadBool(json['allowCoinPayment'], true),
      allowGiftPayment: shopReadBool(json['allowGiftPayment'], true),
      sortOrder: shopReadInt(json['sortOrder']),
      publishedAt: shopReadDate(json['publishedAt']),
      sourcePostId: json['sourcePostId']?.toString(),
      createdAt: shopReadDate(json['createdAt']),
      updatedAt: shopReadDate(json['updatedAt']),
      seller: sellerRaw is Map
          ? ProductSellerModel.fromJson(Map<String, dynamic>.from(sellerRaw))
          : null,
      productCategory: categoryRaw is Map
          ? ProductCategoryModel.fromJson(
              Map<String, dynamic>.from(categoryRaw),
            )
          : null,
      media: mediaRaw is List
          ? mediaRaw
                .whereType<Map>()
                .map(
                  (e) =>
                      ProductMediaModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .where((m) => m.url.isNotEmpty)
                .toList()
          : const [],
      variants: variantsRaw is List
          ? variantsRaw
                .whereType<Map>()
                .map(
                  (e) => ProductVariantModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((v) => v.id.isNotEmpty)
                .toList()
          : const [],
      isFavorite: shopReadBool(json['isFavorite']),
      isLive: shopReadBool(json['isLive']),
    );
  }
}
