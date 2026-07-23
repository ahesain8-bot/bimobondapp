import 'dart:io';

import 'package:bimobondapp/app/posts/data/datasources/posts_remote_data_source.dart';
import 'package:bimobondapp/app/posts/data/models/comment_model.dart';
import 'package:bimobondapp/app/posts/data/models/feed_item_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_page_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_share_result.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_view_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_views_page_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/user_repost_entity.dart';
import 'package:bimobondapp/app/posts/data/models/post_view_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_views_page_model.dart';
import 'package:bimobondapp/core/utils/comment_sort.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/app/social/data/models/social_user_page_model.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/core/data/likes_local_data_source.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:dartz/dartz.dart';

class PostsRepositoryImpl implements PostsRepository {
  final PostsRemoteDataSource remoteDataSource;
  final LikesLocalDataSource likesLocalDataSource;

  PostsRepositoryImpl({
    required this.remoteDataSource,
    required this.likesLocalDataSource,
  });

  String? get _userId => likesLocalDataSource.currentUserId;

  List<PostEntity> _applyPostLikes(List<PostModel> posts) {
    final userId = _userId;
    if (userId == null) return posts;
    return posts
        .map(
          (post) => post.copyWith(
            isLiked: likesLocalDataSource.resolvePostLiked(
              userId,
              post.id,
              post.isLiked,
            ),
          ),
        )
        .toList();
  }

  List<CommentEntity> _applyCommentLikes(List<CommentModel> comments) {
    final userId = _userId;
    if (userId == null) return comments;
    return comments
        .map(
          (comment) => comment.copyWith(
            isLiked: likesLocalDataSource.resolveCommentLiked(
              userId,
              comment.id,
              comment.isLiked,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<Either<Failure, String>> uploadMedia(File file) async {
    try {
      final url = await remoteDataSource.uploadMedia(file);
      return Right(url);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  List<FeedItemEntity> _applyFeedItemLikes(List<FeedItemModel> items) {
    final userId = _userId;
    if (userId == null) return items;

    return items.map((item) {
      final post = item.post;
      if (post is! PostModel) return item;
      final liked = likesLocalDataSource.resolvePostLiked(
        userId,
        post.id,
        post.isLiked,
      );
      return FeedItemModel(
        id: item.id,
        feedType: item.feedType,
        sortAt: item.sortAt,
        post: post.copyWith(isLiked: liked),
        repostId: item.repostId,
        repostedAt: item.repostedAt,
        quote: item.quote,
        repostedBy: item.repostedBy,
      );
    }).toList();
  }

  List<FeedItemEntity> _excludeStoryFeedItems(List<FeedItemEntity> items) =>
      items.where((item) => !item.post.isStory).toList();

  List<FeedItemEntity> _onlyStoryFeedItems(List<FeedItemEntity> items) => items
      .where((item) => item.post.isStory && isStoryStillActive(item.post))
      .toList();

  @override
  Future<Either<Failure, HashtagsPageEntity>> getHashtags({
    int page = 1,
    int limit = 20,
    String? search,
    HashtagSort sort = HashtagSort.name,
  }) async {
    try {
      final result = await remoteDataSource.getHashtags(
        page: page,
        limit: limit,
        search: search,
        sort: sort,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, FeedPageEntity>> getFeed({
    int page = 1,
    int limit = 10,
    String? cursor,
    bool detail = false,
    String? categoryId,
    String? type,
    String? hashtag,
    String? search,
    String? sort,
    String? userId,
    bool? isLiked,
    bool? isSaved,
    bool isStory = false,
    bool activeStory = false,
    FeedContentType? contentType,
    FeedAuctionQuery? auctionQuery,
    String? privacyStatus,
    String? from,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    try {
      // Cursor mode (home feed): send cursor, never bump page.
      // Legacy page mode: send page when cursor is absent.
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty)
          'cursor': cursor
        else
          'page': page,
        if (detail) 'detail': 1,
        if (categoryId != null) 'categoryId': categoryId,
        if (type != null) 'type': type,
        if (hashtag != null) 'hashtag': hashtag,
        if (search != null) 'search': search,
        if (sort != null) 'sort': sort,
        if (userId != null) 'userId': userId,
        if (isLiked != null) 'isLiked': isLiked,
        if (isSaved != null) 'isSaved': isSaved,
        if (privacyStatus != null) 'privacyStatus': privacyStatus,
        if (from != null) 'from': from,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusKm != null) 'radiusKm': radiusKm,
        if (contentType != null && contentType != FeedContentType.all)
          'contentType': contentType.apiValue,
        ...?auctionQuery?.toQueryParams(),
      };

      final pageResult = await remoteDataSource.getFeed(queryParams);
      final withLikes = _applyFeedItemLikes(pageResult.items);
      final filtered = isStory
          ? _onlyStoryFeedItems(withLikes)
          : _excludeStoryFeedItems(withLikes);
      return Right(
        FeedPageEntity(
          items: filtered,
          nextCursor: pageResult.nextCursor,
          hasReachedMax: pageResult.hasReachedMax,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> getPostById(String postId) async {
    try {
      final post = await remoteDataSource.getPostById(postId);
      final posts = _applyPostLikes([post]);
      return Right(posts.first);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> createPost({
    String? type,
    String? videoUrl,
    String? hlsUrl,
    String? thumbnailUrl,
    String? animatedCoverUrl,
    String? description,
    String? categoryId,
    String? status,
    int? duration,
    int? videoWidth,
    int? videoHeight,
    bool? isAd,
    String? privacyStatus,
    bool? allowComments,
    bool? allowDuets,
    bool? allowStitch,
    bool? isStory,
    bool? isAuctionable,
    PostAuctionInput? auction,
    String? locationId,
    PostInlineLocationInput? location,
    String? playlistId,
    String? soundId,
    String? soundSegmentId,
    int? startMs,
    int? endMs,
    Map<String, dynamic>? newSound,
    String? originalPostId,
    List<PostMediaEntity>? media,
    String? filterName,
    String? filterCategory,
    String? effectSlug,
    bool? beautyEnabled,
  }) async {
    try {
      final postData = {
        if (type != null) 'type': type,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (hlsUrl != null) 'hlsUrl': hlsUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (animatedCoverUrl != null) 'animatedCoverUrl': animatedCoverUrl,
        if (description != null) 'description': description,
        if (categoryId != null) 'categoryId': categoryId,
        if (status != null) 'status': status,
        if (duration != null) 'duration': duration,
        if (videoWidth != null) 'videoWidth': videoWidth,
        if (videoHeight != null) 'videoHeight': videoHeight,
        if (isAd != null) 'isAd': isAd,
        if (privacyStatus != null) 'privacyStatus': privacyStatus,
        if (allowComments != null) 'allowComments': allowComments,
        if (allowDuets != null) 'allowDuets': allowDuets,
        if (allowStitch != null) 'allowStitch': allowStitch,
        if (isStory != null) 'isStory': isStory,
        if (isAuctionable != null) 'isAuctionable': isAuctionable,
        if (auction != null) 'auction': auction.toJson(),
        if (locationId != null) 'locationId': locationId,
        if (location != null) 'location': location.toJson(),
        if (playlistId != null && playlistId.isNotEmpty) 'playlistId': playlistId,
        if (soundSegmentId != null && soundSegmentId.isNotEmpty)
          'soundSegmentId': soundSegmentId,
        if (soundId != null &&
            soundId.isNotEmpty &&
            (soundSegmentId == null || soundSegmentId.isEmpty))
          'soundId': soundId,
        if (startMs != null &&
            (soundSegmentId == null || soundSegmentId.isEmpty))
          'startMs': startMs,
        if (endMs != null &&
            (soundSegmentId == null || soundSegmentId.isEmpty))
          'endMs': endMs,
        if (newSound != null &&
            (soundSegmentId == null || soundSegmentId.isEmpty) &&
            (soundId == null || soundId.isEmpty))
          'newSound': newSound,
        if (originalPostId != null) 'originalPostId': originalPostId,
        if (media != null)
          'media': media
              .map((e) => PostMediaModel.fromEntity(e).toJson())
              .toList(),
        if (filterName != null) 'filterName': filterName,
        if (filterCategory != null) 'filterCategory': filterCategory,
        if (effectSlug != null && effectSlug != 'none') 'effectSlug': effectSlug,
        if (beautyEnabled != null) 'beautyEnabled': beautyEnabled,
      };

      final postModel = await remoteDataSource.createPost(postData);
      return Right(postModel);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleLike(
    String postId, {
    required bool liked,
  }) async {
    try {
      final result = await remoteDataSource.toggleLike(postId);
      final userId = _userId;
      if (userId != null) {
        await likesLocalDataSource.setPostLiked(userId, postId, liked);
      }
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SocialUserPageEntity>> getPostLikes(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final pageModel = await remoteDataSource.getPostLikes(
        postId,
        page: page,
        limit: limit,
      );
      return Right(_mapSocialUserPage(pageModel));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, PostViewsPageEntity>> getPostViews(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final pageModel = await remoteDataSource.getPostViews(
        postId,
        page: page,
        limit: limit,
      );
      return Right(_mapPostViewsPage(pageModel));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  PostViewsPageEntity _mapPostViewsPage(PostViewsPageModel pageModel) {
    return PostViewsPageEntity(
      views: pageModel.views
          .whereType<PostViewModel>()
          .map(_mapPostView)
          .toList(),
      page: pageModel.page,
      lastPage: pageModel.lastPage,
      total: pageModel.total,
    );
  }

  PostViewEntity _mapPostView(PostViewModel view) {
    return PostViewEntity(
      id: view.id,
      userId: view.userId,
      postId: view.postId,
      watchedDuration: view.watchedDuration,
      createdAt: view.createdAt,
      user: _mapViewUser(view),
    );
  }

  SocialUserEntity? _mapViewUser(PostViewModel view) {
    final user = view.user;
    if (user != null) {
      return SocialUserEntity(
        id: user.id,
        username: user.username,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
        isActive: user.isActive,
        isFollowing: user.isFollowing,
        isFollowedBy: user.isFollowedBy,
      );
    }
    if (view.userId.isNotEmpty) {
      return SocialUserEntity(id: view.userId);
    }
    return null;
  }

  @override
  Future<Either<Failure, int>> recordPostView(
    String postId, {
    int? watchedDuration,
    String? campaignId,
  }) async {
    try {
      final count = await remoteDataSource.recordPostView(
        postId,
        watchedDuration: watchedDuration,
        campaignId: campaignId,
      );
      return Right(count);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> markPostNotInterested(String postId) async {
    try {
      await remoteDataSource.markPostNotInterested(postId);
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> undoPostNotInterested(String postId) async {
    try {
      await remoteDataSource.undoPostNotInterested(postId);
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> reportPost(
    String postId, {
    required String reason,
    String? details,
  }) async {
    try {
      await remoteDataSource.reportPost(
        postId,
        reason: reason,
        details: details,
      );
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, PostShareResult>> sharePost(
    String postId, {
    String channel = 'EXTERNAL',
  }) async {
    try {
      final json = await remoteDataSource.sharePost(
        postId,
        channel: channel,
      );
      return Right(PostShareResult.fromJson(json));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  SocialUserPageEntity _mapSocialUserPage(SocialUserPageModel pageModel) {
    return SocialUserPageEntity(
      users: pageModel.users
          .map(
            (u) => SocialUserEntity(
              id: u.id,
              username: u.username,
              fullName: u.fullName,
              avatarUrl: u.avatarUrl,
              isActive: u.isActive,
              isFollowing: u.isFollowing,
              isFollowedBy: u.isFollowedBy,
              likedAt: u.likedAt,
            ),
          )
          .toList(growable: false),
      page: pageModel.page,
      lastPage: pageModel.lastPage,
      total: pageModel.total,
    );
  }

  @override
  Future<Either<Failure, bool>> toggleSave(String postId) async {
    try {
      final result = await remoteDataSource.toggleSave(postId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleRepost(
    String postId, {
    String? quote,
  }) async {
    try {
      final result = await remoteDataSource.toggleRepost(postId, quote: quote);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, RepostsPageEntity>> getPostReposts(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await remoteDataSource.getPostReposts(
        postId,
        page: page,
        limit: limit,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, UserRepostsPageEntity>> getMyReposts({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final result = await remoteDataSource.getMyReposts(
        page: page,
        limit: limit,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  Failure _mapPostMutationFailure(AppException e, {required bool isDelete}) {
    if (e is ForbiddenException) {
      return ServerFailure(
        isDelete
            ? 'Only the post owner can delete this post.'
            : 'Only the post owner can edit this post.',
      );
    }
    if (e is UnauthorizedException) {
      return UnauthorizedFailure(
        isDelete
            ? 'Please log in to delete this post.'
            : 'Please log in to edit this post.',
      );
    }
    if (e is NotFoundException) {
      return ServerFailure(isDelete ? 'Post not found.' : 'Post not found.');
    }
    return ServerFailure(e.message ?? 'Something went wrong');
  }

  @override
  Future<Either<Failure, PostEntity>> updatePost(
    String postId, {
    String? description,
    String? categoryId,
    String? privacyStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        if (description != null) 'description': description,
        if (categoryId != null) 'categoryId': categoryId,
        if (privacyStatus != null) 'privacyStatus': privacyStatus,
      };
      final post = await remoteDataSource.updatePost(postId, data);
      return Right(_applyPostLikes([post]).first);
    } on AppException catch (e) {
      return Left(_mapPostMutationFailure(e, isDelete: false));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, bool>> deletePost(String postId) async {
    try {
      final result = await remoteDataSource.deletePost(postId);
      return Right(result);
    } on AppException catch (e) {
      return Left(_mapPostMutationFailure(e, isDelete: true));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
    String sort = 'newest',
  }) async {
    try {
      final result = await remoteDataSource.getComments(postId, {
        'page': page,
        'limit': limit,
        'sort': sort,
      });
      final withLikes = _applyCommentLikes(result);
      return Right(sortCommentsByKey(withLikes, sort));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CommentEntity>> addComment(
    String postId, {
    required String content,
    String? parentId,
  }) async {
    try {
      final result = await remoteDataSource.addComment(postId, {
        'content': content,
        if (parentId != null) 'parentId': parentId,
      });
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getReplies(
    String commentId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await remoteDataSource.getReplies(commentId, {
        'page': page,
        'limit': limit,
      });
      return Right(_applyCommentLikes(result));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteComment(String commentId) async {
    try {
      final result = await remoteDataSource.deleteComment(commentId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleLikeComment(
    String commentId, {
    required bool liked,
  }) async {
    try {
      final result = await remoteDataSource.toggleLikeComment(commentId);
      final userId = _userId;
      if (userId != null) {
        await likesLocalDataSource.setCommentLiked(userId, commentId, liked);
      }
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SocialUserPageEntity>> getCommentLikes(
    String commentId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final pageModel = await remoteDataSource.getCommentLikes(
        commentId,
        page: page,
        limit: limit,
      );
      return Right(_mapSocialUserPage(pageModel));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
