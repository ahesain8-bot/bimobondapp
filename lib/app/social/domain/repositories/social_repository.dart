import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class SocialRepository {
  Future<Either<Failure, FollowStatus>> toggleFollow(String userId);

  Future<Either<Failure, SocialUserPageEntity>> getFollowers(
    SocialListQuery query,
  );

  Future<Either<Failure, SocialUserPageEntity>> getFollowing(
    SocialListQuery query,
  );

  Future<Either<Failure, SocialUserPageEntity>> getMyFriends(
    SocialListQuery query,
  );

  Future<Either<Failure, bool>> isFollowingUser({
    required String currentUserId,
    required String targetUserId,
  });
}
