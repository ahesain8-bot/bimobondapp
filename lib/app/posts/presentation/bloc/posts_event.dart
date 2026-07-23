import 'dart:io';

import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:equatable/equatable.dart';

abstract class PostsEvent extends Equatable {
  const PostsEvent();

  @override
  List<Object?> get props => [];
}

class UploadMediaRequestedEvent extends PostsEvent {
  final File file;
  const UploadMediaRequestedEvent(this.file);

  @override
  List<Object?> get props => [file];
}

class CreatePostRequestedEvent extends PostsEvent {
  final String? type;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? animatedCoverUrl;
  final String? description;
  final String? categoryId;
  final String? status;
  final int? duration;
  final int? videoWidth;
  final int? videoHeight;
  final bool? isAd;
  final String? privacyStatus;
  final bool? allowComments;
  final bool? allowDuets;
  final bool? allowStitch;
  final bool? isStory;
  final bool? isAuctionable;
  final PostAuctionInput? auction;
  final String? locationId;
  final PostInlineLocationInput? location;
  final String? playlistId;
  final String? soundId;
  final String? soundSegmentId;
  final int? startMs;
  final int? endMs;
  final Map<String, dynamic>? newSound;
  final String? originalPostId;
  final List<PostMediaEntity>? media;

  const CreatePostRequestedEvent({
    this.type,
    this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.animatedCoverUrl,
    this.description,
    this.categoryId,
    this.status,
    this.duration,
    this.videoWidth,
    this.videoHeight,
    this.isAd,
    this.privacyStatus,
    this.allowComments,
    this.allowDuets,
    this.allowStitch,
    this.isStory,
    this.isAuctionable,
    this.auction,
    this.locationId,
    this.location,
    this.playlistId,
    this.soundId,
    this.soundSegmentId,
    this.startMs,
    this.endMs,
    this.newSound,
    this.originalPostId,
    this.media,
  });

  @override
  List<Object?> get props => [
    type,
    videoUrl,
    hlsUrl,
    thumbnailUrl,
    animatedCoverUrl,
    description,
    categoryId,
    status,
    duration,
    videoWidth,
    videoHeight,
    isAd,
    privacyStatus,
    allowComments,
    allowDuets,
    allowStitch,
    isStory,
    isAuctionable,
    auction,
    locationId,
    location,
    playlistId,
    soundId,
    soundSegmentId,
    startMs,
    endMs,
    newSound,
    originalPostId,
    media,
  ];
}

class CreatePostWithMediaRequestedEvent extends PostsEvent {
  final String? type;
  final String? description;
  final String? categoryId;
  final String? status;
  final String? privacyStatus;
  final bool? allowComments;
  final bool? allowDuets;
  final bool? allowStitch;
  final bool isAuctionable;
  final bool isStory;
  final PostAuctionInput? auction;
  final List<File> files;
  final String? soundId;
  final String? soundSegmentId;
  final int? startMs;
  final int? endMs;
  final Map<String, dynamic>? newSound;
  final String? filterName;
  final String? filterCategory;
  final String? effectSlug;
  final bool? beautyEnabled;
  final PostInlineLocationInput? location;

  const CreatePostWithMediaRequestedEvent({
    this.type,
    this.description,
    this.categoryId,
    this.status,
    this.privacyStatus,
    this.allowComments,
    this.allowDuets,
    this.allowStitch,
    this.isAuctionable = false,
    this.isStory = false,
    this.auction,
    required this.files,
    this.soundId,
    this.soundSegmentId,
    this.startMs,
    this.endMs,
    this.newSound,
    this.filterName,
    this.filterCategory,
    this.effectSlug,
    this.beautyEnabled,
    this.location,
  });

  @override
  List<Object?> get props => [
    type,
    description,
    categoryId,
    privacyStatus,
    allowComments,
    allowDuets,
    allowStitch,
    status,
    isAuctionable,
    isStory,
    auction,
    files,
    soundId,
    soundSegmentId,
    startMs,
    endMs,
    newSound,
    filterName,
    filterCategory,
    effectSlug,
    beautyEnabled,
    location,
  ];
}

class ToggleLikePostRequestedEvent extends PostsEvent {
  final String postId;
  final bool liked;

  const ToggleLikePostRequestedEvent(this.postId, {required this.liked});

  @override
  List<Object?> get props => [postId, liked];
}

class ToggleSavePostRequestedEvent extends PostsEvent {
  final String postId;
  const ToggleSavePostRequestedEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class ToggleRepostPostRequestedEvent extends PostsEvent {
  final String postId;
  final String? quote;

  const ToggleRepostPostRequestedEvent(this.postId, {this.quote});

  @override
  List<Object?> get props => [postId, quote];
}

class FetchMyRepostsRequestedEvent extends PostsEvent {
  final int page;
  final int limit;
  final bool isRefresh;
  final int? profileLoadKey;

  const FetchMyRepostsRequestedEvent({
    this.page = 1,
    this.limit = 10,
    this.isRefresh = false,
    this.profileLoadKey,
  });

  @override
  List<Object?> get props => [page, limit, isRefresh, profileLoadKey];
}

class UpdatePostRequestedEvent extends PostsEvent {
  final String postId;
  final String? description;
  final String? categoryId;
  final String? privacyStatus;

  const UpdatePostRequestedEvent({
    required this.postId,
    this.description,
    this.categoryId,
    this.privacyStatus,
  });

  @override
  List<Object?> get props => [postId, description, categoryId, privacyStatus];
}

class DeletePostRequestedEvent extends PostsEvent {
  final String postId;
  final bool isStory;

  const DeletePostRequestedEvent(this.postId, {this.isStory = false});

  @override
  List<Object?> get props => [postId, isStory];
}

class HidePostFromFeedEvent extends PostsEvent {
  const HidePostFromFeedEvent(this.postId, {this.syncApi = true});

  final String postId;

  /// When false, only remove locally (e.g. after report already marked NI).
  final bool syncApi;

  @override
  List<Object?> get props => [postId, syncApi];
}

class FetchFeedRequestedEvent extends PostsEvent {
  final int page;
  final int limit;
  /// Opaque cursor from the previous page (`meta.nextCursor`). Prefer over [page].
  final String? cursor;
  final String? categoryId;
  final String? type;
  final String? hashtag;
  final String? search;
  final String? sort;
  final String? userId;
  final bool? isLiked;
  final bool? isSaved;

  /// `false` for posts feed/profile; must stay false for non-story lists.
  final bool isStory;
  final FeedContentType? contentType;
  final bool isRefresh;
  final int? profileLoadKey;
  final String? privacyStatus;
  final String? from;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  /// When set, forwards auction filters (e.g. exclude auctions from home feed).
  final FeedAuctionQuery? auctionQuery;

  const FetchFeedRequestedEvent({
    this.page = 1,
    this.limit = 10,
    this.cursor,
    this.categoryId,
    this.type,
    this.hashtag,
    this.search,
    this.sort,
    this.userId,
    this.isLiked,
    this.isSaved,
    this.isStory = false,
    this.contentType,
    this.isRefresh = false,
    this.profileLoadKey,
    this.privacyStatus,
    this.from,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.auctionQuery,
  });

  @override
  List<Object?> get props => [
    page,
    limit,
    cursor,
    categoryId,
    type,
    hashtag,
    search,
    sort,
    userId,
    isLiked,
    isSaved,
    isStory,
    contentType,
    isRefresh,
    profileLoadKey,
    privacyStatus,
    from,
    latitude,
    longitude,
    radiusKm,
    auctionQuery,
  ];
}

class FetchStoriesRequestedEvent extends PostsEvent {
  final int page;
  final int limit;
  final bool isRefresh;

  const FetchStoriesRequestedEvent({
    this.page = 1,
    this.limit = 10,
    this.isRefresh = false,
  });

  @override
  List<Object?> get props => [page, limit, isRefresh];
}
