import 'package:bimobondapp/app/posts/data/models/mention_ref_model.dart';
import 'package:bimobondapp/app/posts/data/models/repost_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_sound_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_promotion_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/mention_ref_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';

class PostModel extends PostEntity {
  const PostModel({
    required super.id,
    required super.userId,
    required super.type,
    super.videoUrl,
    super.hlsUrl,
    super.thumbnailUrl,
    super.description,
    super.categoryId,
    required super.privacyStatus,
    required super.viewCount,
    required super.likeCount,
    required super.commentCount,
    required super.saveCount,
    required super.shareCount,
    required super.repostCount,
    required super.isLiked,
    required super.isSaved,
    required super.isReposted,
    super.recentReposters = const [],
    required super.createdAt,
    PostUserModel? super.user,
    required List<PostMediaModel> super.media,
    required super.hashtags,
    required super.mentions,
    super.isAuctionable = false,
    super.isStory = false,
    super.auction,
    super.isPromoted = false,
    super.isAd = false,
    super.promotion,
    super.location,
    super.sound,
    super.filterName,
  });

  static List<String> _parseHashtagNames(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is String) return e;
          if (e is Map) return e['name']?.toString() ?? '';
          return e.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static PostSoundEntity? _soundFromId(dynamic raw) {
    final id = raw?.toString();
    if (id == null || id.isEmpty) return null;
    return PostSoundEntity(id: id, name: 'Original Sound');
  }

  static String? _normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  static String? _parseCategoryId(Map<String, dynamic> json) {
    final direct = json['categoryId']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;

    final nested = json['category'];
    if (nested is Map) {
      final nestedId = nested['id']?.toString();
      if (nestedId != null && nestedId.isNotEmpty) return nestedId;
    }
    return null;
  }

  static int _parseRepostCount(Map<String, dynamic> json) {
    final direct = json['repostCount'];
    if (direct is int) return direct;
    if (direct is num) return direct.toInt();
    final count = json['_count'];
    if (count is Map) {
      final nested = count['reposts'];
      if (nested is int) return nested;
      if (nested is num) return nested.toInt();
    }
    return 0;
  }

  static bool _parseBoolField(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static List<RepostUserModel> _parseRecentReposters(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => RepostUserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static String? _parseFilterName(Map<String, dynamic> json) {
    final raw = json['filterName'] ?? json['filter_name'] ?? json['cameraFilter'];
    final name = raw?.toString().trim();
    if (name == null || name.isEmpty) return null;
    if (name == 'None' || name == 'Original') return null;
    return name;
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? 'VIDEO',
      videoUrl: _normalizeUrl(json['videoUrl']),
      hlsUrl: _normalizeUrl(json['hlsUrl']),
      thumbnailUrl: _normalizeUrl(json['thumbnailUrl']),
      description: json['description'],
      categoryId: _parseCategoryId(json),
      privacyStatus: json['privacyStatus'] ?? 'PUBLIC',
      viewCount: json['viewCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      saveCount: json['saveCount'] ?? 0,
      shareCount: json['shareCount'] ?? 0,
      repostCount: _parseRepostCount(json),
      isLiked: json['isLiked'] is bool
          ? json['isLiked'] as bool
          : json['isLiked']?.toString().toLowerCase() == 'true',
      isSaved: _parseBoolField(json['isSaved']),
      isReposted: _parseBoolField(json['isReposted']),
      recentReposters: _parseRecentReposters(
        json['recentReposters'] ?? json['recentReposts'],
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      user: json['user'] != null
          ? PostUserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      media:
          (json['media'] as List<dynamic>?)
              ?.map((e) => PostMediaModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hashtags: _parseHashtagNames(json['hashtags']),
      mentions: MentionRefModel.listFromJson(json['mentions']),
      isAuctionable: json['isAuctionable'] == true,
      isStory: parsePostIsStory(json['isStory']),
      auction: json['auction'] is Map<String, dynamic>
          ? PostAuctionEntity.fromJson(json['auction'] as Map<String, dynamic>)
          : null,
      isPromoted: PostModel._parseBoolField(json['isPromoted']),
      isAd: PostModel._parseBoolField(json['isAd']),
      promotion: json['promotion'] is Map<String, dynamic>
          ? PostPromotionEntity.fromJson(json['promotion'] as Map<String, dynamic>)
          : null,
      location: json['location'] is Map<String, dynamic>
          ? PostLocationEntity.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      sound: json['sound'] is Map<String, dynamic>
          ? PostSoundEntity.fromJson(json['sound'] as Map<String, dynamic>)
          : _soundFromId(json['soundId']),
      filterName: _parseFilterName(json),
    );
  }

  PostModel copyWith({
    int? commentCount,
    int? likeCount,
    int? saveCount,
    int? repostCount,
    bool? isLiked,
    bool? isSaved,
    bool? isReposted,
    List<RepostUserEntity>? recentReposters,
    String? description,
    String? privacyStatus,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      type: type,
      videoUrl: videoUrl,
      hlsUrl: hlsUrl,
      thumbnailUrl: thumbnailUrl,
      description: description ?? this.description,
      categoryId: categoryId,
      privacyStatus: privacyStatus ?? this.privacyStatus,
      viewCount: viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      shareCount: shareCount,
      repostCount: repostCount ?? this.repostCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isReposted: isReposted ?? this.isReposted,
      recentReposters: recentReposters ?? this.recentReposters,
      createdAt: createdAt,
      user: user as PostUserModel?,
      media: media.cast<PostMediaModel>(),
      hashtags: hashtags,
      mentions: mentions,
      isAuctionable: isAuctionable,
      isStory: isStory,
      auction: auction,
      isPromoted: isPromoted,
      isAd: isAd,
      promotion: promotion,
      location: location,
      sound: sound,
      filterName: filterName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'videoUrl': videoUrl,
      'hlsUrl': hlsUrl,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'categoryId': categoryId,
      'privacyStatus': privacyStatus,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'saveCount': saveCount,
      'shareCount': shareCount,
      'repostCount': repostCount,
      'isLiked': isLiked,
      'isSaved': isSaved,
      'isReposted': isReposted,
      'createdAt': createdAt.toIso8601String(),
      'user': (user as PostUserModel?)?.toJson(),
      'media': media.map((e) => (e as PostMediaModel).toJson()).toList(),
      'hashtags': hashtags,
      'mentions': mentions
          .map(
            (e) => e is MentionRefModel
                ? e.toJson()
                : MentionRefModel(
                    userId: e.userId,
                    username: e.username,
                  ).toJson(),
          )
          .toList(),
      'isAuctionable': isAuctionable,
      if (auction != null) 'auction': _auctionToJson(auction!),
      if (filterName != null) 'filterName': filterName,
    };
  }

  static Map<String, dynamic> _auctionToJson(PostAuctionEntity auction) => {
    if (auction.id != null) 'id': auction.id,
    'itemName': auction.itemName,
    'itemImageUrl': auction.itemImageUrl,
    'startingPriceUsd': auction.startingPriceUsd,
    'targetPriceUsd': auction.targetPriceUsd,
    'currentTotalUsd': auction.currentTotalUsd,
    'giftCount': auction.giftCount,
    'startedAt': auction.startedAt.toUtc().toIso8601String(),
    'endedAt': auction.endedAt.toUtc().toIso8601String(),
  };
}

class PostUserModel extends PostUserEntity {
  const PostUserModel({
    required super.id,
    required super.username,
    super.fullName,
    super.avatarUrl,
    super.isFollowing,
  });

  static bool? _parseOptionalBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'followed':
        case 'following':
          return true;
        case 'false':
        case '0':
        case 'unfollowed':
          return false;
      }
    }
    return null;
  }

  factory PostUserModel.fromJson(Map<String, dynamic> json) {
    return PostUserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? json['displayName']?.toString(),
      avatarUrl: PostModel._normalizeUrl(json['avatarUrl']),
      isFollowing:
          _parseOptionalBool(json['isFollowing']) ??
          _parseOptionalBool(json['isFollowed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      if (isFollowing != null) 'isFollowing': isFollowing,
    };
  }
}

class PostMediaModel extends PostMediaEntity {
  const PostMediaModel({
    required super.url,
    required super.mediaType,
    super.order,
  });

  factory PostMediaModel.fromJson(Map<String, dynamic> json) {
    return PostMediaModel(
      url: PostModel._normalizeUrl(json['url']) ?? '',
      mediaType: json['mediaType'] ?? 'IMAGE',
      order: json['order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'mediaType': mediaType, 'order': order};
  }

  factory PostMediaModel.fromEntity(PostMediaEntity entity) {
    return PostMediaModel(
      url: entity.url,
      mediaType: entity.mediaType,
      order: entity.order,
    );
  }
}
