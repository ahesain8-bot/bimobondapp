import 'package:bimobondapp/app/posts/domain/entities/post_auction_entity.dart';
import 'package:equatable/equatable.dart';

class PostEntity extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? description;
  final String? category;
  final String privacyStatus;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final bool isLiked;
  final bool isSaved;
  final DateTime createdAt;
  final PostUserEntity? user;
  final List<PostMediaEntity> media;
  final List<String> hashtags;
  final List<String> mentions;
  final bool isAuctionable;
  final PostAuctionEntity? auction;

  const PostEntity({
    required this.id,
    required this.userId,
    required this.type,
    this.videoUrl,
    this.thumbnailUrl,
    this.description,
    this.category,
    required this.privacyStatus,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.isLiked,
    required this.isSaved,
    required this.createdAt,
    this.user,
    required this.media,
    required this.hashtags,
    required this.mentions,
    this.isAuctionable = false,
    this.auction,
  });

  PostEntity copyWith({
    int? commentCount,
    int? likeCount,
    int? saveCount,
    bool? isLiked,
    bool? isSaved,
    String? description,
    String? privacyStatus,
  }) {
    return PostEntity(
      id: id,
      userId: userId,
      type: type,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      description: description ?? this.description,
      category: category,
      privacyStatus: privacyStatus ?? this.privacyStatus,
      viewCount: viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      shareCount: shareCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt,
      user: user,
      media: media,
      hashtags: hashtags,
      mentions: mentions,
      isAuctionable: isAuctionable,
      auction: auction,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    videoUrl,
    thumbnailUrl,
    description,
    category,
    privacyStatus,
    viewCount,
    likeCount,
    commentCount,
    saveCount,
    shareCount,
    isLiked,
    isSaved,
    createdAt,
    user,
    media,
    hashtags,
    mentions,
    isAuctionable,
    auction,
  ];
}

class PostUserEntity extends Equatable {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool? isFollowing;

  const PostUserEntity({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isFollowing,
  });

  @override
  List<Object?> get props => [id, username, avatarUrl, isFollowing];
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
