import 'dart:io';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_views_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class PostsRepository {
  Future<Either<Failure, String>> uploadMedia(File file);
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
    String? playlistId,
    String? soundId,
    String? originalPostId,
    List<PostMediaEntity>? media,
  });

  Future<Either<Failure, List<PostEntity>>> getFeed({
    int page = 1,
    int limit = 10,
    String? categoryId,
    String? type,
    String? hashtag,
    String? search,
    String? sort,
    String? userId,
    bool? isLiked,
    bool? isSaved,
    bool isStory = false,
    FeedAuctionQuery? auctionQuery,
  });

  Future<Either<Failure, PostEntity>> getPostById(String postId);

  Future<Either<Failure, bool>> toggleLike(
    String postId, {
    required bool liked,
  });
  Future<Either<Failure, SocialUserPageEntity>> getPostLikes(
    String postId, {
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, PostViewsPageEntity>> getPostViews(
    String postId, {
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, int>> recordPostView(
    String postId, {
    int? watchedDuration,
  });
  Future<Either<Failure, bool>> toggleSave(String postId);
  Future<Either<Failure, PostEntity>> updatePost(
    String postId, {
    String? description,
    String? categoryId,
    String? privacyStatus,
  });
  Future<Either<Failure, bool>> deletePost(String postId);

  // Comments
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
    String sort = 'newest',
  });
  Future<Either<Failure, CommentEntity>> addComment(
    String postId, {
    required String content,
    String? parentId,
  });
  Future<Either<Failure, List<CommentEntity>>> getReplies(
    String commentId, {
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, bool>> deleteComment(String commentId);
  Future<Either<Failure, bool>> toggleLikeComment(
    String commentId, {
    required bool liked,
  });
}
