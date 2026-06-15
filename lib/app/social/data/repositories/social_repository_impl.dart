import 'package:bimobondapp/app/social/data/datasources/social_remote_data_source.dart';
import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comments_page_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_like_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_likes_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mentions_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class SocialRepositoryImpl implements SocialRepository {
  SocialRepositoryImpl({required this.remoteDataSource});

  final SocialRemoteDataSource remoteDataSource;

  Failure _mapException(Object e) {
    if (e is ServerException) {
      return ServerFailure(e.message ?? 'Something went wrong');
    }
    if (e is UnauthorizedException) {
      return UnauthorizedFailure(e.message ?? 'Unauthorized');
    }
    return ServerFailure(e.toString());
  }

  @override
  Future<Either<Failure, FollowStatus>> toggleFollow(String userId) async {
    try {
      final status = await remoteDataSource.toggleFollow(userId);
      return Right(status);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, SocialUserPageEntity>> getFollowers(
    SocialListQuery query,
  ) async {
    try {
      final page = await remoteDataSource.getFollowers(query);
      return Right(page);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, SocialUserPageEntity>> getFollowing(
    SocialListQuery query,
  ) async {
    try {
      final page = await remoteDataSource.getFollowing(query);
      return Right(page);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, SocialUserPageEntity>> getMyFriends(
    SocialListQuery query,
  ) async {
    try {
      final page = await remoteDataSource.getMyFriends(query);
      return Right(page);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, List<UserSuggestionEntity>>> getSuggestions({
    int limit = 20,
  }) async {
    try {
      final suggestions = await remoteDataSource.getSuggestions(limit: limit);
      return Right(
        suggestions.map(UserSuggestionEntity.from).toList(growable: true),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, UserCommentsPageEntity>> getUserComments({
    String? userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final pageResult = await remoteDataSource.getUserComments(
        userId: userId,
        page: page,
        limit: limit,
      );
      return Right(
        UserCommentsPageEntity(
          comments: pageResult.comments
              .map(_commentToEntity)
              .toList(growable: true),
          page: pageResult.page,
          lastPage: pageResult.lastPage,
          total: pageResult.total,
        ),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  UserCommentEntity _commentToEntity(UserCommentEntity comment) {
    return UserCommentEntity(
      id: comment.id,
      content: comment.content,
      postId: comment.postId,
      userId: comment.userId,
      parentId: comment.parentId,
      likeCount: comment.likeCount,
      replyCount: comment.replyCount,
      isGift: comment.isGift,
      giftId: comment.giftId,
      createdAt: comment.createdAt,
      updatedAt: comment.updatedAt,
      user: comment.user == null
          ? null
          : SocialUserEntity(
              id: comment.user!.id,
              username: comment.user!.username,
              fullName: comment.user!.fullName,
              avatarUrl: comment.user!.avatarUrl,
              isFollowing: comment.user!.isFollowing,
              isFollowedBy: comment.user!.isFollowedBy,
            ),
      post: comment.post == null
          ? null
          : UserCommentPostEntity(
              id: comment.post!.id,
              description: comment.post!.description,
              user: comment.post!.user == null
                  ? null
                  : SocialUserEntity(
                      id: comment.post!.user!.id,
                      username: comment.post!.user!.username,
                      fullName: comment.post!.user!.fullName,
                      avatarUrl: comment.post!.user!.avatarUrl,
                      isFollowing: comment.post!.user!.isFollowing,
                      isFollowedBy: comment.post!.user!.isFollowedBy,
                    ),
            ),
    );
  }

  @override
  Future<Either<Failure, UserLikesPageEntity>> getMyLikes({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final pageResult = await remoteDataSource.getMyLikes(
        page: page,
        limit: limit,
      );
      return Right(
        UserLikesPageEntity(
          likes: pageResult.likes.map(_likeToEntity).toList(growable: true),
          page: pageResult.page,
          lastPage: pageResult.lastPage,
          total: pageResult.total,
        ),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  UserLikeEntity _likeToEntity(UserLikeEntity like) {
    return UserLikeEntity(
      id: like.id,
      postId: like.postId,
      createdAt: like.createdAt,
      user: like.user == null
          ? null
          : SocialUserEntity(
              id: like.user!.id,
              username: like.user!.username,
              fullName: like.user!.fullName,
              avatarUrl: like.user!.avatarUrl,
              isFollowing: like.user!.isFollowing,
              isFollowedBy: like.user!.isFollowedBy,
            ),
      post: like.post == null ? null : _postToEntity(like.post!),
    );
  }

  @override
  Future<Either<Failure, UserMentionsPageEntity>> getMyMentions({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final pageResult = await remoteDataSource.getMyMentions(
        page: page,
        limit: limit,
      );
      return Right(
        UserMentionsPageEntity(
          mentions: pageResult.mentions
              .map(_mentionToEntity)
              .toList(growable: true),
          page: pageResult.page,
          lastPage: pageResult.lastPage,
          total: pageResult.total,
        ),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  UserMentionEntity _mentionToEntity(UserMentionEntity mention) {
    return UserMentionEntity(
      id: mention.id,
      sourceType: mention.sourceType,
      postId: mention.postId,
      commentId: mention.commentId,
      content: mention.content,
      createdAt: mention.createdAt,
      user: mention.user == null
          ? null
          : SocialUserEntity(
              id: mention.user!.id,
              username: mention.user!.username,
              fullName: mention.user!.fullName,
              avatarUrl: mention.user!.avatarUrl,
              isFollowing: mention.user!.isFollowing,
              isFollowedBy: mention.user!.isFollowedBy,
            ),
      post: mention.post == null ? null : _postToEntity(mention.post!),
    );
  }

  PostEntity _postToEntity(PostEntity post) {
    return PostEntity(
      id: post.id,
      userId: post.userId,
      type: post.type,
      videoUrl: post.videoUrl,
      hlsUrl: post.hlsUrl,
      thumbnailUrl: post.thumbnailUrl,
      description: post.description,
      categoryId: post.categoryId,
      privacyStatus: post.privacyStatus,
      viewCount: post.viewCount,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      saveCount: post.saveCount,
      shareCount: post.shareCount,
      repostCount: post.repostCount,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      isReposted: post.isReposted,
      recentReposters: post.recentReposters,
      createdAt: post.createdAt,
      user: post.user == null
          ? null
          : PostUserEntity(
              id: post.user!.id,
              username: post.user!.username,
              avatarUrl: post.user!.avatarUrl,
              isFollowing: post.user!.isFollowing,
            ),
      media: post.media,
      hashtags: post.hashtags,
      mentions: post.mentions,
      isAuctionable: post.isAuctionable,
      isStory: post.isStory,
      auction: post.auction,
    );
  }

  @override
  Future<Either<Failure, bool>> isFollowingUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      var page = 1;
      const limit = 50;

      while (true) {
        final result = await remoteDataSource.getFollowing(
          SocialListQuery(userId: currentUserId, page: page, limit: limit),
        );

        if (result.users.any((user) => user.id == targetUserId)) {
          return const Right(true);
        }

        if (result.hasReachedMax) {
          return const Right(false);
        }

        page++;
      }
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
