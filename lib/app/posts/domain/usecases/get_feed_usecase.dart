import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_page_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetFeedUseCase implements UseCase<FeedPageEntity, GetFeedParams> {
  GetFeedUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, FeedPageEntity>> call(GetFeedParams params) {
    return repository.getFeed(
      page: params.page,
      limit: params.limit,
      cursor: params.cursor,
      detail: params.detail,
      categoryId: params.categoryId,
      type: params.type,
      hashtag: params.hashtag,
      search: params.search,
      sort: params.sort,
      userId: params.userId,
      isLiked: params.isLiked,
      isSaved: params.isSaved,
      isStory: params.isStory,
      activeStory: params.activeStory,
      contentType: params.contentType,
      auctionQuery: params.auctionQuery,
      privacyStatus: params.privacyStatus,
      from: params.from,
      latitude: params.latitude,
      longitude: params.longitude,
      radiusKm: params.radiusKm,
    );
  }
}

class GetFeedParams extends Equatable {
  const GetFeedParams({
    this.page = 1,
    this.limit = 10,
    this.cursor,
    this.detail = false,
    this.categoryId,
    this.type,
    this.hashtag,
    this.search,
    this.sort,
    this.userId,
    this.isLiked,
    this.isSaved,
    this.isStory = false,
    this.activeStory = false,
    this.contentType,
    this.auctionQuery,
    this.privacyStatus,
    this.from,
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  final int page;
  final int limit;

  /// When set, uses cursor pagination (preferred for home feed).
  final String? cursor;

  /// Heavy cards (`auction` / `sound` / `location`). Never enable on home feed.
  final bool detail;
  final String? categoryId;
  final String? type;
  final String? hashtag;
  final String? search;
  final String? sort;
  final String? userId;
  final bool? isLiked;
  final bool? isSaved;
  final bool isStory;
  final bool activeStory;
  final FeedContentType? contentType;
  final FeedAuctionQuery? auctionQuery;
  final String? privacyStatus;
  final String? from;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;

  @override
  List<Object?> get props => [
    page,
    limit,
    cursor,
    detail,
    categoryId,
    type,
    hashtag,
    search,
    sort,
    userId,
    isLiked,
    isSaved,
    isStory,
    activeStory,
    contentType,
    auctionQuery,
    privacyStatus,
    from,
    latitude,
    longitude,
    radiusKm,
  ];
}
