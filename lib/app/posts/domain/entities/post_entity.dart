import 'package:bimobondapp/app/posts/domain/entities/mention_ref_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_promotion_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_sound_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:equatable/equatable.dart';

class PostEntity extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? description;
  final String? categoryId;
  final String privacyStatus;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final int repostCount;
  final bool isLiked;
  final bool isSaved;
  final bool isReposted;
  final List<RepostUserEntity> recentReposters;
  final DateTime createdAt;
  final PostUserEntity? user;
  final List<PostMediaEntity> media;
  final List<String> hashtags;
  final List<MentionRefEntity> mentions;
  final bool isAuctionable;
  final bool isStory;
  final PostAuctionEntity? auction;
  final bool isPromoted;
  final bool isAd;
  final PostPromotionEntity? promotion;
  final PostLocationEntity? location;
  final PostSoundEntity? sound;
  final String? filterName;

  const PostEntity({
    required this.id,
    required this.userId,
    required this.type,
    this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.description,
    this.categoryId,
    required this.privacyStatus,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.repostCount,
    required this.isLiked,
    required this.isSaved,
    required this.isReposted,
    this.recentReposters = const [],
    required this.createdAt,
    this.user,
    required this.media,
    required this.hashtags,
    required this.mentions,
    this.isAuctionable = false,
    this.isStory = false,
    this.auction,
    this.isPromoted = false,
    this.isAd = false,
    this.promotion,
    this.location,
    this.sound,
    this.filterName,
  });

  PostEntity copyWith({
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
    return PostEntity(
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
      user: user,
      media: media,
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

  /// Public videos and auctions (non-stories) can be promoted by their owner.
  bool get canBePromoted => !isStory && privacyStatus == 'PUBLIC';

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    videoUrl,
    hlsUrl,
    thumbnailUrl,
    description,
    categoryId,
    privacyStatus,
    viewCount,
    likeCount,
    commentCount,
    saveCount,
    shareCount,
    repostCount,
    isLiked,
    isSaved,
    isReposted,
    recentReposters,
    createdAt,
    user,
    media,
    hashtags,
    mentions,
    isAuctionable,
    isStory,
    auction,
    isPromoted,
    isAd,
    promotion,
    location,
    sound,
    filterName,
  ];
}

class PostUserEntity extends Equatable {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool? isFollowing;

  const PostUserEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isFollowing,
  });

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl, isFollowing];
}

class PostMediaEntity extends Equatable {
  final String url;
  final String mediaType;
  final int? order;

  const PostMediaEntity({
    required this.url,
    required this.mediaType,
    this.order,
  });

  @override
  List<Object?> get props => [url, mediaType, order];
}
