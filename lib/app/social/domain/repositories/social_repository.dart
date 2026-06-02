import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comments_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_likes_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mentions_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
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

  Future<Either<Failure, List<UserSuggestionEntity>>> getSuggestions({
    int limit = 20,
  });

  Future<Either<Failure, UserCommentsPageEntity>> getUserComments({
    String? userId,
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, UserLikesPageEntity>> getMyLikes({
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, UserMentionsPageEntity>> getMyMentions({
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, bool>> isFollowingUser({
    required String currentUserId,
    required String targetUserId,
  });
}
