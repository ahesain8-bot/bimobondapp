import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetFeedUseCase implements UseCase<List<FeedItemEntity>, GetFeedParams> {
  GetFeedUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, List<FeedItemEntity>>> call(GetFeedParams params) {
    return repository.getFeed(
      page: params.page,
      limit: params.limit,
      categoryId: params.categoryId,
      type: params.type,
      hashtag: params.hashtag,
      search: params.search,
      sort: params.sort,
      userId: params.userId,
      isLiked: params.isLiked,
      isSaved: params.isSaved,
      isStory: params.isStory,
      contentType: params.contentType,
      auctionQuery: params.auctionQuery,
      privacyStatus: params.privacyStatus,
    );
  }
}

class GetFeedParams extends Equatable {
  const GetFeedParams({
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
    this.contentType,
    this.auctionQuery,
    this.privacyStatus,
  });

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
  final bool isStory;
  final FeedContentType? contentType;
  final FeedAuctionQuery? auctionQuery;
  final String? privacyStatus;

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
    contentType,
    auctionQuery,
    privacyStatus,
  ];
}
