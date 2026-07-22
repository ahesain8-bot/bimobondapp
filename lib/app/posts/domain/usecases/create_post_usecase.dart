import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class CreatePostUseCase implements UseCase<PostEntity, CreatePostParams> {
  final PostsRepository repository;

  CreatePostUseCase(this.repository);

  @override
  Future<Either<Failure, PostEntity>> call(CreatePostParams params) async {
    return await repository.createPost(
      type: params.type,
      videoUrl: params.videoUrl,
      hlsUrl: params.hlsUrl,
      thumbnailUrl: params.thumbnailUrl,
      animatedCoverUrl: params.animatedCoverUrl,
      description: params.description,
      categoryId: params.categoryId,
      status: params.status,
      duration: params.duration,
      videoWidth: params.videoWidth,
      videoHeight: params.videoHeight,
      isAd: params.isAd,
      privacyStatus: params.privacyStatus,
      allowComments: params.allowComments,
      allowDuets: params.allowDuets,
      allowStitch: params.allowStitch,
      isStory: params.isStory,
      isAuctionable: params.isAuctionable,
      auction: params.auction,
      locationId: params.locationId,
      location: params.location,
      playlistId: params.playlistId,
      soundId: params.soundId,
      soundSegmentId: params.soundSegmentId,
      startMs: params.startMs,
      endMs: params.endMs,
      newSound: params.newSound,
      originalPostId: params.originalPostId,
      media: params.media,
      filterName: params.filterName,
      filterCategory: params.filterCategory,
      effectSlug: params.effectSlug,
      beautyEnabled: params.beautyEnabled,
    );
  }
}

class CreatePostParams extends Equatable {
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
  final String? filterName;
  final String? filterCategory;
  final String? effectSlug;
  final bool? beautyEnabled;

  const CreatePostParams({
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
    this.filterName,
    this.filterCategory,
    this.effectSlug,
    this.beautyEnabled,
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
    filterName,
    filterCategory,
    effectSlug,
    beautyEnabled,
  ];
}
