import 'dart:io';

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
  final String? playlistId;
  final String? soundId;
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
    this.playlistId,
    this.soundId,
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
    playlistId,
    soundId,
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

  const DeletePostRequestedEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

class FetchFeedRequestedEvent extends PostsEvent {
  final int page;
  final int limit;
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
  final bool isRefresh;
  final int? profileLoadKey;

  const FetchFeedRequestedEvent({
    this.page = 1,
    this.limit = 10,
    this.categoryId,
    this.type,
    this.hashtag,
    this.search,
    this.sort,
    this.userId,
    this.isLiked,
    this.isSaved,
    this.isStory = false,
    this.isRefresh = false,
    this.profileLoadKey,
  });

  @override
  List<Object?> get props => [
    page,
    limit,
    categoryId,
    type,
    hashtag,
    search,
    sort,
    userId,
    isLiked,
    isSaved,
    isStory,
    isRefresh,
    profileLoadKey,
  ];
}

class FetchStoriesRequestedEvent extends PostsEvent {
  final int page;
  final int limit;
  final bool isRefresh;

  const FetchStoriesRequestedEvent({
    this.page = 1,
    this.limit = 30,
    this.isRefresh = false,
  });

  @override
  List<Object?> get props => [page, limit, isRefresh];
}
