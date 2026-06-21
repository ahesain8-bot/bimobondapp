import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:equatable/equatable.dart';

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class PaginationMetaEntity extends Equatable {
  const PaginationMetaEntity({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory PaginationMetaEntity.fromJson(Map<String, dynamic> json) {
    return PaginationMetaEntity(
      total: _parseInt(json['total']),
      page: _parseInt(json['page'], fallback: 1),
      limit: _parseInt(json['limit'], fallback: 20),
      totalPages: _parseInt(json['totalPages'], fallback: 1),
    );
  }

  @override
  List<Object?> get props => [total, page, limit, totalPages];
}

class LocationHistoryPointEntity extends Equatable {
  const LocationHistoryPointEntity({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.createdAt,
    this.accuracy,
    this.altitude,
    this.city,
    this.region,
    this.country,
  });

  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final String? city;
  final String? region;
  final String? country;
  final String source;
  final DateTime createdAt;

  factory LocationHistoryPointEntity.fromJson(Map<String, dynamic> json) {
    return LocationHistoryPointEntity(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      accuracy: _parseDouble(json['accuracy']),
      altitude: _parseDouble(json['altitude']),
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      country: json['country']?.toString(),
      source: json['source']?.toString() ?? 'MANUAL',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, latitude, longitude, accuracy, altitude, city, region, country, source, createdAt];
}

class LocationHistoryPageEntity extends Equatable {
  const LocationHistoryPageEntity({
    required this.data,
    required this.meta,
  });

  final List<LocationHistoryPointEntity> data;
  final PaginationMetaEntity meta;

  factory LocationHistoryPageEntity.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return LocationHistoryPageEntity(
      data: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => LocationHistoryPointEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      meta: PaginationMetaEntity.fromJson(
        Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
      ),
    );
  }

  @override
  List<Object?> get props => [data, meta];
}

class LocationMovementsEntity extends Equatable {
  const LocationMovementsEntity({
    required this.userId,
    required this.points,
    required this.meta,
  });

  final String userId;
  final List<LocationHistoryPointEntity> points;
  final Map<String, dynamic> meta;

  factory LocationMovementsEntity.fromJson(Map<String, dynamic> json) {
    final raw = json['points'];
    return LocationMovementsEntity(
      userId: json['userId']?.toString() ?? '',
      points: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => LocationHistoryPointEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      meta: Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
    );
  }

  @override
  List<Object?> get props => [userId, points, meta];
}

class PromotionOptionItemEntity extends Equatable {
  const PromotionOptionItemEntity({
    required this.value,
    required this.label,
    this.description,
  });

  final String value;
  final String label;
  final String? description;

  factory PromotionOptionItemEntity.fromJson(Map<String, dynamic> json) {
    return PromotionOptionItemEntity(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }

  @override
  List<Object?> get props => [value, label, description];
}

class PromotionCategoryOptionEntity extends Equatable {
  const PromotionCategoryOptionEntity({
    required this.id,
    required this.name,
    this.slug,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String? slug;
  final String? iconUrl;

  factory PromotionCategoryOptionEntity.fromJson(Map<String, dynamic> json) {
    return PromotionCategoryOptionEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      iconUrl: json['iconUrl']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, slug, iconUrl];
}

class PromoteRegionalTownEntity extends Equatable {
  const PromoteRegionalTownEntity({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory PromoteRegionalTownEntity.fromJson(Map<String, dynamic> json) {
    return PromoteRegionalTownEntity(
      id: json['id']?.toString() ?? json['value']?.toString() ?? '',
      name: json['name']?.toString() ?? json['label']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class PromoteRegionalRegionEntity extends Equatable {
  const PromoteRegionalRegionEntity({
    required this.id,
    required this.name,
    required this.towns,
  });

  final String id;
  final String name;
  final List<PromoteRegionalTownEntity> towns;

  factory PromoteRegionalRegionEntity.fromJson(Map<String, dynamic> json) {
    final rawTowns = json['towns'] ?? json['cities'];
    return PromoteRegionalRegionEntity(
      id: json['id']?.toString() ?? json['value']?.toString() ?? '',
      name: json['name']?.toString() ?? json['label']?.toString() ?? '',
      towns: rawTowns is List
          ? rawTowns
              .whereType<Map>()
              .map(
                (e) => PromoteRegionalTownEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((t) => t.id.isNotEmpty && t.name.isNotEmpty)
              .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [id, name, towns];
}

class PromoteRegionalCountryEntity extends Equatable {
  const PromoteRegionalCountryEntity({
    required this.code,
    required this.name,
    required this.regions,
  });

  final String code;
  final String name;
  final List<PromoteRegionalRegionEntity> regions;

  factory PromoteRegionalCountryEntity.fromJson(Map<String, dynamic> json) {
    final rawRegions = json['regions'];
    return PromoteRegionalCountryEntity(
      code: json['code']?.toString() ?? json['value']?.toString() ?? '',
      name: json['name']?.toString() ?? json['label']?.toString() ?? '',
      regions: rawRegions is List
          ? rawRegions
              .whereType<Map>()
              .map(
                (e) => PromoteRegionalRegionEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((r) => r.id.isNotEmpty && r.name.isNotEmpty)
              .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [code, name, regions];
}

class PromotionOptionsEntity extends Equatable {
  const PromotionOptionsEntity({
    required this.objectives,
    required this.genders,
    required this.languages,
    required this.categories,
    required this.countries,
    required this.ageMin,
    required this.ageMax,
  });

  final List<PromotionOptionItemEntity> objectives;
  final List<PromotionOptionItemEntity> genders;
  final List<PromotionOptionItemEntity> languages;
  final List<PromotionCategoryOptionEntity> categories;
  final List<PromoteRegionalCountryEntity> countries;
  final int ageMin;
  final int ageMax;

  factory PromotionOptionsEntity.fromJson(Map<String, dynamic> json) {
    final ageRange = json['ageRange'];
    return PromotionOptionsEntity(
      objectives: _items(json['objectives']),
      genders: _items(json['genders']),
      languages: _items(json['languages']),
      categories: json['categories'] is List
          ? (json['categories'] as List)
              .whereType<Map>()
              .map(
                (e) => PromotionCategoryOptionEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      countries: json['countries'] is List
          ? (json['countries'] as List)
              .whereType<Map>()
              .map(
                (e) => PromoteRegionalCountryEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((c) => c.code.isNotEmpty && c.name.isNotEmpty)
              .toList()
          : const [],
      ageMin: ageRange is Map ? _parseInt(ageRange['min'], fallback: 13) : 13,
      ageMax: ageRange is Map ? _parseInt(ageRange['max'], fallback: 100) : 100,
    );
  }

  static List<PromotionOptionItemEntity> _items(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => PromotionOptionItemEntity.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  @override
  List<Object?> get props =>
      [objectives, genders, languages, categories, countries, ageMin, ageMax];
}

class PromotionPackageEntity extends Equatable {
  const PromotionPackageEntity({
    required this.id,
    required this.name,
    required this.priceUsd,
    required this.impressionCount,
    required this.isActive,
  });

  final String id;
  final String name;
  final double priceUsd;
  final int impressionCount;
  final bool isActive;

  factory PromotionPackageEntity.fromJson(Map<String, dynamic> json) {
    return PromotionPackageEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priceUsd: _parseDouble(json['priceUsd']) ?? 0,
      impressionCount: _parseInt(json['impressionCount']),
      isActive: json['isActive'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, priceUsd, impressionCount, isActive];
}

class PromotionCampaignEntity extends Equatable {
  const PromotionCampaignEntity({
    required this.id,
    required this.postId,
    required this.packageId,
    required this.status,
    required this.objective,
    required this.budgetUsd,
    this.targetGenders = const [],
    this.targetAgeMin,
    this.targetAgeMax,
    this.targetCountryCodes = const [],
    this.targetLanguages = const [],
    this.targetCategoryIds = const [],
    this.targetLatitude,
    this.targetLongitude,
    this.targetRadiusKm,
  });

  final String id;
  final String postId;
  final String packageId;
  final String status;
  final String objective;
  final double budgetUsd;
  final List<String> targetGenders;
  final int? targetAgeMin;
  final int? targetAgeMax;
  final List<String> targetCountryCodes;
  final List<String> targetLanguages;
  final List<String> targetCategoryIds;
  final double? targetLatitude;
  final double? targetLongitude;
  final double? targetRadiusKm;

  factory PromotionCampaignEntity.fromJson(Map<String, dynamic> json) {
    final post = json['post'];
    final nestedPostId =
        post is Map ? post['id']?.toString() : null;
    final package = json['package'];
    final nestedPackageId =
        package is Map ? package['id']?.toString() : null;

    return PromotionCampaignEntity(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? nestedPostId ?? '',
      packageId: json['packageId']?.toString() ?? nestedPackageId ?? '',
      status: json['status']?.toString() ?? 'PENDING_PAYMENT',
      objective: json['objective']?.toString() ?? 'VIEWS',
      budgetUsd: _parseDouble(json['budgetUsd']) ?? 0,
      targetGenders: _strings(json['targetGenders']),
      targetAgeMin: json['targetAgeMin'] == null
          ? null
          : _parseInt(json['targetAgeMin']),
      targetAgeMax: json['targetAgeMax'] == null
          ? null
          : _parseInt(json['targetAgeMax']),
      targetCountryCodes: _strings(json['targetCountryCodes']),
      targetLanguages: _strings(json['targetLanguages']),
      targetCategoryIds: _strings(json['targetCategoryIds']),
      targetLatitude: _parseDouble(json['targetLatitude']),
      targetLongitude: _parseDouble(json['targetLongitude']),
      targetRadiusKm: _parseDouble(json['targetRadiusKm']),
    );
  }

  static List<String> _strings(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> toCreateJson({
    required String postId,
    required String packageId,
  }) {
    return {
      'postId': postId,
      'packageId': packageId,
      'objective': objective,
      if (targetGenders.isNotEmpty) 'targetGenders': targetGenders,
      if (targetAgeMin != null) 'targetAgeMin': targetAgeMin,
      if (targetAgeMax != null) 'targetAgeMax': targetAgeMax,
      if (targetCountryCodes.isNotEmpty) 'targetCountryCodes': targetCountryCodes,
      if (targetLanguages.isNotEmpty) 'targetLanguages': targetLanguages,
      if (targetCategoryIds.isNotEmpty) 'targetCategoryIds': targetCategoryIds,
      if (targetLatitude != null) 'targetLatitude': targetLatitude,
      if (targetLongitude != null) 'targetLongitude': targetLongitude,
      if (targetRadiusKm != null) 'targetRadiusKm': targetRadiusKm,
    };
  }

  @override
  List<Object?> get props =>
      [id, postId, packageId, status, objective, budgetUsd, targetGenders, targetAgeMin, targetAgeMax, targetCountryCodes, targetLanguages, targetCategoryIds, targetLatitude, targetLongitude, targetRadiusKm];
}

class PromotionPayResultEntity extends Equatable {
  const PromotionPayResultEntity({
    required this.success,
    required this.newBalance,
    required this.campaign,
  });

  final bool success;
  final double newBalance;
  final PromotionCampaignEntity campaign;

  factory PromotionPayResultEntity.fromJson(Map<String, dynamic> json) {
    final campaignRaw = json['campaign'];
    return PromotionPayResultEntity(
      success: json['success'] == true,
      newBalance: _parseDouble(json['newBalance']) ?? 0,
      campaign: campaignRaw is Map
          ? PromotionCampaignEntity.fromJson(
              Map<String, dynamic>.from(campaignRaw),
            )
          : const PromotionCampaignEntity(
              id: '',
              postId: '',
              packageId: '',
              status: 'ACTIVE',
              objective: 'VIEWS',
              budgetUsd: 0,
            ),
    );
  }

  @override
  List<Object?> get props => [success, newBalance, campaign];
}

// ─── Promoted posts & analytics ─────────────────────────────────────────────

class PromotedPostMediaEntity extends Equatable {
  const PromotedPostMediaEntity({
    required this.url,
    required this.mediaType,
  });

  final String url;
  final String mediaType;

  factory PromotedPostMediaEntity.fromJson(Map<String, dynamic> json) {
    return PromotedPostMediaEntity(
      url: json['url']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'IMAGE',
    );
  }

  @override
  List<Object?> get props => [url, mediaType];
}

class PromotedPostInfoEntity extends Equatable {
  const PromotedPostInfoEntity({
    required this.id,
    this.thumbnailUrl,
    this.imageUrl,
    this.auctionItemImageUrl,
    this.media = const [],
    this.description,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isAd = false,
    this.isAuctionable = false,
  });

  final String id;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String? auctionItemImageUrl;
  final List<PromotedPostMediaEntity> media;
  final String? description;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final bool isAd;
  final bool isAuctionable;

  factory PromotedPostInfoEntity.fromJson(Map<String, dynamic> json) {
    final auction = json['auction'];
    String? auctionImage;
    if (auction is Map) {
      auctionImage = auction['itemImageUrl']?.toString() ??
          auction['imageUrl']?.toString();
    }

    final mediaRaw = json['media'];
    final media = mediaRaw is List
        ? mediaRaw
            .whereType<Map>()
            .map(
              (e) => PromotedPostMediaEntity.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .where((m) => m.url.isNotEmpty)
            .toList()
        : const <PromotedPostMediaEntity>[];

    return PromotedPostInfoEntity(
      id: json['id']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ??
          json['thumbnail']?.toString() ??
          json['postThumbnailUrl']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['coverUrl']?.toString(),
      auctionItemImageUrl: auctionImage,
      media: media,
      description: json['description']?.toString(),
      viewCount: _parseInt(json['viewCount']),
      likeCount: _parseInt(json['likeCount']),
      commentCount: _parseInt(json['commentCount']),
      isAd: json['isAd'] == true,
      isAuctionable: json['isAuctionable'] == true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        thumbnailUrl,
        imageUrl,
        auctionItemImageUrl,
        media,
        description,
        viewCount,
        likeCount,
        commentCount,
        isAd,
        isAuctionable,
      ];
}

/// Best cover image for a promoted post card (thumbnail, auction image, media).
String? resolvePromotedPostCoverUrl(PromotedPostInfoEntity post) {
  final candidates = <String?>[
    post.auctionItemImageUrl,
    post.thumbnailUrl,
    post.imageUrl,
    for (final item in post.media)
      if (MediaUtils.isImage(item.url, mediaType: item.mediaType)) item.url,
    for (final item in post.media)
      if (!MediaUtils.isVideo(item.url, mediaType: item.mediaType)) item.url,
  ];

  for (final raw in candidates) {
    if (raw == null || raw.trim().isEmpty) continue;
    final resolved = MediaUtils.resolveAbsoluteUrl(raw.trim());
    if (resolved.isEmpty) continue;
    if (MediaUtils.isVideo(resolved) && !MediaUtils.isLikelyImageUrl(resolved)) {
      continue;
    }
    return resolved;
  }
  return null;
}

class PostEngagementStatisticsEntity extends Equatable {
  const PostEngagementStatisticsEntity({
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.reposts = 0,
    this.totalEngagements = 0,
    this.engagementRate = 0,
    this.promotedImpressions = 0,
    this.uniquePromotedViewers = 0,
    this.followersGained = 0,
    this.promotionSpendUsd = 0,
    this.costPerImpression = 0,
    this.costPerView = 0,
  });

  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int reposts;
  final int totalEngagements;
  final double engagementRate;
  final int promotedImpressions;
  final int uniquePromotedViewers;
  final int followersGained;
  final double promotionSpendUsd;
  final double costPerImpression;
  final double costPerView;

  factory PostEngagementStatisticsEntity.fromJson(Map<String, dynamic> json) {
    return PostEngagementStatisticsEntity(
      views: _parseInt(json['views'] ?? json['viewCount']),
      likes: _parseInt(json['likes'] ?? json['likeCount']),
      comments: _parseInt(json['comments'] ?? json['commentCount']),
      shares: _parseInt(json['shares'] ?? json['shareCount']),
      saves: _parseInt(json['saves'] ?? json['saveCount']),
      reposts: _parseInt(json['reposts'] ?? json['repostCount']),
      totalEngagements: _parseInt(json['totalEngagements']),
      engagementRate: _parseDouble(json['engagementRate']) ?? 0,
      promotedImpressions: _parseInt(json['promotedImpressions']),
      uniquePromotedViewers: _parseInt(json['uniquePromotedViewers']),
      followersGained: _parseInt(json['followersGained']),
      promotionSpendUsd: _parseDouble(json['promotionSpendUsd']) ?? 0,
      costPerImpression: _parseDouble(json['costPerImpression']) ?? 0,
      costPerView: _parseDouble(json['costPerView']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        views,
        likes,
        comments,
        shares,
        saves,
        reposts,
        totalEngagements,
        engagementRate,
        promotedImpressions,
        uniquePromotedViewers,
        followersGained,
        promotionSpendUsd,
        costPerImpression,
        costPerView,
      ];
}

class PromotionAggregateEntity extends Equatable {
  const PromotionAggregateEntity({
    this.totalCampaigns = 0,
    this.activeCampaigns = 0,
    this.totalImpressions = 0,
    this.totalSpentUsd = 0,
    this.averageCostPerImpression = 0,
  });

  final int totalCampaigns;
  final int activeCampaigns;
  final int totalImpressions;
  final double totalSpentUsd;
  final double averageCostPerImpression;

  factory PromotionAggregateEntity.fromJson(Map<String, dynamic> json) {
    return PromotionAggregateEntity(
      totalCampaigns: _parseInt(json['totalCampaigns']),
      activeCampaigns: _parseInt(json['activeCampaigns']),
      totalImpressions: _parseInt(json['totalImpressions']),
      totalSpentUsd: _parseDouble(json['totalSpentUsd']) ?? 0,
      averageCostPerImpression:
          _parseDouble(json['averageCostPerImpression']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        totalCampaigns,
        activeCampaigns,
        totalImpressions,
        totalSpentUsd,
        averageCostPerImpression,
      ];
}

class PromotionCampaignProgressEntity extends Equatable {
  const PromotionCampaignProgressEntity({
    this.impressionCount = 0,
    this.impressionTarget = 0,
    this.progressPercent = 0,
    this.spentUsd = 0,
    this.budgetUsd = 0,
    this.impressionsLeft = 0,
    this.budgetLeft = 0,
    this.costPerImpression = 0,
  });

  final int impressionCount;
  final int impressionTarget;
  final double progressPercent;
  final double spentUsd;
  final double budgetUsd;
  final int impressionsLeft;
  final double budgetLeft;
  final double costPerImpression;

  factory PromotionCampaignProgressEntity.fromJson(Map<String, dynamic> json) {
    return PromotionCampaignProgressEntity(
      impressionCount: _parseInt(json['impressionCount']),
      impressionTarget: _parseInt(json['impressionTarget']),
      progressPercent: _parseDouble(json['progressPercent']) ?? 0,
      spentUsd: _parseDouble(json['spentUsd']) ?? 0,
      budgetUsd: _parseDouble(json['budgetUsd']) ?? 0,
      impressionsLeft: _parseInt(json['impressionsLeft']),
      budgetLeft: _parseDouble(json['budgetLeft']) ?? 0,
      costPerImpression: _parseDouble(json['costPerImpression']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        impressionCount,
        impressionTarget,
        progressPercent,
        spentUsd,
        budgetUsd,
        impressionsLeft,
        budgetLeft,
        costPerImpression,
      ];
}

class PromotionCampaignSummaryEntity extends Equatable {
  const PromotionCampaignSummaryEntity({
    required this.id,
    required this.status,
    required this.objective,
    this.progress,
    this.createdAt,
  });

  final String id;
  final String status;
  final String objective;
  final PromotionCampaignProgressEntity? progress;
  final DateTime? createdAt;

  factory PromotionCampaignSummaryEntity.fromJson(Map<String, dynamic> json) {
    final progressRaw = json['progress'];
    return PromotionCampaignSummaryEntity(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      objective: json['objective']?.toString() ?? 'VIEWS',
      progress: progressRaw is Map
          ? PromotionCampaignProgressEntity.fromJson(
              Map<String, dynamic>.from(progressRaw),
            )
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, status, objective, progress, createdAt];
}

class PromotedPostRowEntity extends Equatable {
  const PromotedPostRowEntity({
    required this.post,
    required this.statistics,
    required this.promotion,
    this.primaryCampaign,
    this.campaigns = const [],
  });

  final PromotedPostInfoEntity post;
  final PostEngagementStatisticsEntity statistics;
  final PromotionAggregateEntity promotion;
  final PromotionCampaignSummaryEntity? primaryCampaign;
  final List<PromotionCampaignSummaryEntity> campaigns;

  factory PromotedPostRowEntity.fromJson(Map<String, dynamic> json) {
    final postRaw = json['post'];
    final statsRaw = json['statistics'];
    final promoRaw = json['promotion'];
    final primaryRaw = json['primaryCampaign'];
    final campaignsRaw = json['campaigns'];

    return PromotedPostRowEntity(
      post: postRaw is Map
          ? PromotedPostInfoEntity.fromJson(Map<String, dynamic>.from(postRaw))
          : const PromotedPostInfoEntity(id: ''),
      statistics: statsRaw is Map
          ? PostEngagementStatisticsEntity.fromJson(
              Map<String, dynamic>.from(statsRaw),
            )
          : const PostEngagementStatisticsEntity(),
      promotion: promoRaw is Map
          ? PromotionAggregateEntity.fromJson(
              Map<String, dynamic>.from(promoRaw),
            )
          : const PromotionAggregateEntity(),
      primaryCampaign: primaryRaw is Map
          ? PromotionCampaignSummaryEntity.fromJson(
              Map<String, dynamic>.from(primaryRaw),
            )
          : null,
      campaigns: campaignsRaw is List
          ? campaignsRaw
              .whereType<Map>()
              .map(
                (e) => PromotionCampaignSummaryEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
  }

  @override
  List<Object?> get props =>
      [post, statistics, promotion, primaryCampaign, campaigns];
}

class PromotedPostsPageEntity extends Equatable {
  const PromotedPostsPageEntity({
    required this.data,
    required this.meta,
  });

  final List<PromotedPostRowEntity> data;
  final PaginationMetaEntity meta;

  factory PromotedPostsPageEntity.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return PromotedPostsPageEntity(
      data: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => PromotedPostRowEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      meta: PaginationMetaEntity.fromJson(
        Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
      ),
    );
  }

  @override
  List<Object?> get props => [data, meta];
}

class DailyImpressionEntity extends Equatable {
  const DailyImpressionEntity({
    required this.date,
    required this.count,
  });

  final String date;
  final int count;

  factory DailyImpressionEntity.fromJson(Map<String, dynamic> json) {
    return DailyImpressionEntity(
      date: json['date']?.toString() ?? '',
      count: _parseInt(json['count']),
    );
  }

  @override
  List<Object?> get props => [date, count];
}

class PromotionChartsEntity extends Equatable {
  const PromotionChartsEntity({
    this.impressionsLast7Days = const [],
    this.totalRecordedImpressions = 0,
    this.totalPromotionCostUsd = 0,
  });

  final List<DailyImpressionEntity> impressionsLast7Days;
  final int totalRecordedImpressions;
  final double totalPromotionCostUsd;

  factory PromotionChartsEntity.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['impressionsLast7Days'];
    return PromotionChartsEntity(
      impressionsLast7Days: daysRaw is List
          ? daysRaw
              .whereType<Map>()
              .map(
                (e) => DailyImpressionEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      totalRecordedImpressions: _parseInt(json['totalRecordedImpressions']),
      totalPromotionCostUsd:
          _parseDouble(json['totalPromotionCostUsd']) ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [impressionsLast7Days, totalRecordedImpressions, totalPromotionCostUsd];
}

class PromotedPostStatsEntity extends Equatable {
  const PromotedPostStatsEntity({
    required this.post,
    required this.statistics,
    required this.promotion,
    this.primaryCampaign,
    this.campaigns = const [],
    this.charts = const PromotionChartsEntity(),
  });

  final PromotedPostInfoEntity post;
  final PostEngagementStatisticsEntity statistics;
  final PromotionAggregateEntity promotion;
  final PromotionCampaignSummaryEntity? primaryCampaign;
  final List<PromotionCampaignSummaryEntity> campaigns;
  final PromotionChartsEntity charts;

  factory PromotedPostStatsEntity.fromJson(Map<String, dynamic> json) {
    final postRaw = json['post'];
    final statsRaw = json['statistics'];
    final promoRaw = json['promotion'];
    final primaryRaw = json['primaryCampaign'];
    final campaignsRaw = json['campaigns'];
    final chartsRaw = json['charts'];

    return PromotedPostStatsEntity(
      post: postRaw is Map
          ? PromotedPostInfoEntity.fromJson(Map<String, dynamic>.from(postRaw))
          : const PromotedPostInfoEntity(id: ''),
      statistics: statsRaw is Map
          ? PostEngagementStatisticsEntity.fromJson(
              Map<String, dynamic>.from(statsRaw),
            )
          : const PostEngagementStatisticsEntity(),
      promotion: promoRaw is Map
          ? PromotionAggregateEntity.fromJson(
              Map<String, dynamic>.from(promoRaw),
            )
          : const PromotionAggregateEntity(),
      primaryCampaign: primaryRaw is Map
          ? PromotionCampaignSummaryEntity.fromJson(
              Map<String, dynamic>.from(primaryRaw),
            )
          : null,
      campaigns: campaignsRaw is List
          ? campaignsRaw
              .whereType<Map>()
              .map(
                (e) => PromotionCampaignSummaryEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      charts: chartsRaw is Map
          ? PromotionChartsEntity.fromJson(
              Map<String, dynamic>.from(chartsRaw),
            )
          : const PromotionChartsEntity(),
    );
  }

  @override
  List<Object?> get props =>
      [post, statistics, promotion, primaryCampaign, campaigns, charts];
}

class CampaignStatsEntity extends Equatable {
  const CampaignStatsEntity({
    required this.campaign,
    this.progress = const PromotionCampaignProgressEntity(),
  });

  final PromotionCampaignSummaryEntity campaign;
  final PromotionCampaignProgressEntity progress;

  factory CampaignStatsEntity.fromJson(Map<String, dynamic> json) {
    final campaignRaw = json['campaign'] ?? json;
    final progressRaw = json['progress'];

    PromotionCampaignSummaryEntity campaign;
    PromotionCampaignProgressEntity progress;

    if (campaignRaw is Map) {
      final map = Map<String, dynamic>.from(campaignRaw);
      final nestedProgress = map['progress'];
      campaign = PromotionCampaignSummaryEntity.fromJson(map);
      progress = nestedProgress is Map
          ? PromotionCampaignProgressEntity.fromJson(
              Map<String, dynamic>.from(nestedProgress),
            )
          : campaign.progress ?? const PromotionCampaignProgressEntity();
    } else {
      campaign = const PromotionCampaignSummaryEntity(
        id: '',
        status: '',
        objective: 'VIEWS',
      );
      progress = const PromotionCampaignProgressEntity();
    }

    if (progressRaw is Map) {
      progress = PromotionCampaignProgressEntity.fromJson(
        Map<String, dynamic>.from(progressRaw),
      );
    }

    return CampaignStatsEntity(campaign: campaign, progress: progress);
  }

  @override
  List<Object?> get props => [campaign, progress];
}
