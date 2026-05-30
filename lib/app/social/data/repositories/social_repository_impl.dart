import 'package:bimobondapp/app/social/data/datasources/social_remote_data_source.dart';
import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
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
