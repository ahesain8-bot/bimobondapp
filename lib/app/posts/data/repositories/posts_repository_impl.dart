import 'dart:io';

import 'package:bimobondapp/app/posts/data/datasources/posts_remote_data_source.dart';
import 'package:bimobondapp/app/posts/data/models/comment_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/data/likes_local_data_source.dart';
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
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      final queryParams = {
        'page': page,
        'limit': limit,
        if (category != null) 'category': category,
        if (type != null) 'type': type,
        if (hashtag != null) 'hashtag': hashtag,
        if (search != null) 'search': search,
        if (sort != null) 'sort': sort,
        if (userId != null) 'userId': userId,
        if (isLiked != null) 'isLiked': isLiked,
        if (isSaved != null) 'isSaved': isSaved,
      };

      final posts = await remoteDataSource.getFeed(queryParams);
      return Right(_applyPostLikes(posts));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PostEntity>> getPostById(String postId) async {
    try {
      final post = await remoteDataSource.getPostById(postId);
      final posts = _applyPostLikes([post]);
      return Right(posts.first);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
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
  }) async {
    try {
      final postData = {
        if (type != null) 'type': type,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (hlsUrl != null) 'hlsUrl': hlsUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (animatedCoverUrl != null) 'animatedCoverUrl': animatedCoverUrl,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
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
        if (playlistId != null) 'playlistId': playlistId,
        if (soundId != null) 'soundId': soundId,
        if (originalPostId != null) 'originalPostId': originalPostId,
        if (media != null)
          'media': media
              .map((e) => PostMediaModel.fromEntity(e).toJson())
              .toList(),
      };

      final postModel = await remoteDataSource.createPost(postData);
      return Right(postModel);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
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
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleSave(String postId) async {
    try {
      final result = await remoteDataSource.toggleSave(postId);
      return Right(result);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
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
    String? category,
    String? privacyStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (privacyStatus != null) 'privacyStatus': privacyStatus,
      };
      final post = await remoteDataSource.updatePost(postId, data);
      return Right(_applyPostLikes([post]).first);
    } on AppException catch (e) {
      return Left(_mapPostMutationFailure(e, isDelete: false));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
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
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CommentEntity>>> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await remoteDataSource.getComments(postId, {
        'page': page,
        'limit': limit,
      });
      return Right(_applyCommentLikes(result));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
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
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
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
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteComment(String commentId) async {
    try {
      final result = await remoteDataSource.deleteComment(commentId);
      return Right(result);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
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
    } on AppException catch (e) {
      return Left(ServerFailure(e.message!));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
