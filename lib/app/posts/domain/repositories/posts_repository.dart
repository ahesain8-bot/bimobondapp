import 'dart:io';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
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
    String? category,
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
    String? category,
    String? type,
    String? hashtag,
    String? search,
    String? sort,
    String? userId,
    bool? isLiked,
    bool? isSaved,
  });

  Future<Either<Failure, bool>> toggleLike(
    String postId, {
    required bool liked,
  });
  Future<Either<Failure, bool>> toggleSave(String postId);
  Future<Either<Failure, PostEntity>> updatePost(
    String postId, {
    String? description,
    String? category,
    String? privacyStatus,
  });
  Future<Either<Failure, bool>> deletePost(String postId);

  // Comments
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
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
