import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetFeedUseCase implements UseCase<List<PostEntity>, GetFeedParams> {
  final PostsRepository repository;

  GetFeedUseCase(this.repository);

  @override
  Future<Either<Failure, List<PostEntity>>> call(GetFeedParams params) async {
    return await repository.getFeed(
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
      auctionQuery: params.auctionQuery,
    );
  }
}

class GetFeedParams extends Equatable {
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
  /// `false` for posts feed/profile; `true` for stories.
  final bool isStory;
  final FeedAuctionQuery? auctionQuery;

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
    this.auctionQuery,
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
    auctionQuery,
  ];
}
