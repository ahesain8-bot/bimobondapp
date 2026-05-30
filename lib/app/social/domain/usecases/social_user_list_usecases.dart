import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetFollowersUseCase
    implements UseCase<SocialUserPageEntity, GetUserListParams> {
  GetFollowersUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, SocialUserPageEntity>> call(
    GetUserListParams params,
  ) {
    return repository.getFollowers(params.query);
  }
}

class GetFollowingUseCase
    implements UseCase<SocialUserPageEntity, GetUserListParams> {
  GetFollowingUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, SocialUserPageEntity>> call(
    GetUserListParams params,
  ) {
    return repository.getFollowing(params.query);
  }
}

class GetMyFriendsUseCase
    implements UseCase<SocialUserPageEntity, SocialListQuery> {
  GetMyFriendsUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, SocialUserPageEntity>> call(
    SocialListQuery params,
  ) {
    return repository.getMyFriends(params);
  }
}

class CheckIsFollowingUseCase
    implements UseCase<bool, CheckIsFollowingParams> {
  CheckIsFollowingUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, bool>> call(CheckIsFollowingParams params) {
    return repository.isFollowingUser(
      currentUserId: params.currentUserId,
      targetUserId: params.targetUserId,
    );
  }
}

class GetUserListParams extends Equatable {
  const GetUserListParams(this.userId, {this.page = 1, this.limit = 20});

  final String userId;
  final int page;
  final int limit;

  SocialListQuery get query =>
      SocialListQuery(userId: userId, page: page, limit: limit);

  @override
  List<Object?> get props => [userId, page, limit];
}

class CheckIsFollowingParams extends Equatable {
  const CheckIsFollowingParams({
    required this.currentUserId,
    required this.targetUserId,
  });

  final String currentUserId;
  final String targetUserId;

  @override
  List<Object?> get props => [currentUserId, targetUserId];
}
