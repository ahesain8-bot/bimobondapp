import 'package:equatable/equatable.dart';

enum ProductMediaType { image, video, carousel }

enum ProductStatus { draft, active, paused, archived, unknown }

/// Payload item for `POST /products` → `media[]`.
class ProductMediaInput {
  const ProductMediaInput({
    required this.url,
    required this.mediaType,
    this.sortOrder = 0,
  });

  final String url;
  final ProductMediaType mediaType;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'url': url,
        'mediaType': mediaType == ProductMediaType.video ? 'VIDEO' : 'IMAGE',
        'sortOrder': sortOrder,
      };
}

class ProductMediaEntity extends Equatable {
  const ProductMediaEntity({
    required this.id,
    required this.url,
    required this.mediaType,
    this.hlsUrl,
    this.sortOrder = 0,
    this.width,
    this.height,
    this.duration,
  });

  final String id;
  final String url;
  final ProductMediaType mediaType;
  final String? hlsUrl;
  final int sortOrder;
  final int? width;
  final int? height;
  final int? duration;

  @override
  List<Object?> get props =>
      [id, url, mediaType, hlsUrl, sortOrder, width, height, duration];
}

class ProductVariantEntity extends Equatable {
  const ProductVariantEntity({
    required this.id,
    required this.name,
    required this.priceCoins,
    this.sku,
    this.stockQuantity = 0,
    this.imageUrl,
    this.attributes = const {},
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int priceCoins;
  final String? sku;
  final int stockQuantity;
  final String? imageUrl;
  final Map<String, dynamic> attributes;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [
        id,
        name,
        priceCoins,
        sku,
        stockQuantity,
        imageUrl,
        attributes,
        sortOrder,
        isActive,
      ];
}

class ProductSellerEntity extends Equatable {
  const ProductSellerEntity({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.showShopOnProfile,
    this.verificationBadge,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final bool? showShopOnProfile;
  final String? verificationBadge;

  @override
  List<Object?> get props =>
      [id, username, avatarUrl, showShopOnProfile, verificationBadge];
}

class ProductCategoryEntity extends Equatable {
  const ProductCategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, slug, iconUrl, sortOrder, isActive];
}

/// Catalog product aligned with Nest `GET /products` response.
class ProductEntity extends Equatable {
  const ProductEntity({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.priceCoins,
    this.description,
    this.slug,
    this.status = ProductStatus.active,
    this.mediaType = ProductMediaType.image,
    this.coverImageUrl,
    this.thumbnailUrl,
    this.videoUrl,
    this.hlsUrl,
    this.duration,
    this.productCategoryId,
    this.compareAtCoins,
    this.currencyCode = 'USD',
    this.stockQuantity = 0,
    this.trackInventory = true,
    this.allowCoinPayment = true,
    this.allowGiftPayment = true,
    this.sortOrder = 0,
    this.publishedAt,
    this.sourcePostId,
    this.createdAt,
    this.updatedAt,
    this.seller,
    this.productCategory,
    this.media = const [],
    this.variants = const [],
    this.isFavorite = false,
    this.isLive = false,
  });

  final String id;
  final String sellerId;
  final String title;
  final String? description;
  final String? slug;
  final ProductStatus status;
  final ProductMediaType mediaType;
  final String? coverImageUrl;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? hlsUrl;
  final int? duration;
  final String? productCategoryId;
  final int priceCoins;
  final int? compareAtCoins;
  final String currencyCode;
  final int stockQuantity;
  final bool trackInventory;
  final bool allowCoinPayment;
  final bool allowGiftPayment;
  final int sortOrder;
  final DateTime? publishedAt;
  final String? sourcePostId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ProductSellerEntity? seller;
  final ProductCategoryEntity? productCategory;
  final List<ProductMediaEntity> media;
  final List<ProductVariantEntity> variants;
  final bool isFavorite;
  final bool isLive;

  String get name => title;

  String? get displayImageUrl =>
      thumbnailUrl ?? coverImageUrl ?? (media.isNotEmpty ? media.first.url : null);

  bool get hasDiscount =>
      compareAtCoins != null && compareAtCoins! > priceCoins;

  int get discountPercentage {
    if (!hasDiscount) return 0;
    final compare = compareAtCoins!;
    return (((compare - priceCoins) / compare) * 100).round().clamp(0, 99);
  }

  bool get inStock => !trackInventory || stockQuantity > 0;

  bool get isVideo => mediaType == ProductMediaType.video;

  ProductEntity copyWith({
    bool? isFavorite,
    bool? isLive,
  }) {
    return ProductEntity(
      id: id,
      sellerId: sellerId,
      title: title,
      description: description,
      slug: slug,
      status: status,
      mediaType: mediaType,
      coverImageUrl: coverImageUrl,
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      hlsUrl: hlsUrl,
      duration: duration,
      productCategoryId: productCategoryId,
      priceCoins: priceCoins,
      compareAtCoins: compareAtCoins,
      currencyCode: currencyCode,
      stockQuantity: stockQuantity,
      trackInventory: trackInventory,
      allowCoinPayment: allowCoinPayment,
      allowGiftPayment: allowGiftPayment,
      sortOrder: sortOrder,
      publishedAt: publishedAt,
      sourcePostId: sourcePostId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      seller: seller,
      productCategory: productCategory,
      media: media,
      variants: variants,
      isFavorite: isFavorite ?? this.isFavorite,
      isLive: isLive ?? this.isLive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sellerId,
        title,
        description,
        slug,
        status,
        mediaType,
        coverImageUrl,
        thumbnailUrl,
        videoUrl,
        hlsUrl,
        duration,
        productCategoryId,
        priceCoins,
        compareAtCoins,
        currencyCode,
        stockQuantity,
        trackInventory,
        allowCoinPayment,
        allowGiftPayment,
        sortOrder,
        publishedAt,
        sourcePostId,
        createdAt,
        updatedAt,
        seller,
        productCategory,
        media,
        variants,
        isFavorite,
        isLive,
      ];
}
