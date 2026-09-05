import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;

/// Ensures users you already follow are marked [SocialUserEntity.isFollowing]
/// so the button shows "Following" instead of "Follow back".
///
/// Follower list payloads often omit viewer follow flags (or nest them wrong).
Future<List<SocialUserEntity>> enrichSocialFollowState(
  List<SocialUserEntity> users, {
  required String currentUserId,
}) async {
  if (users.isEmpty || currentUserId.isEmpty) return users;

  final needsCheck = users
      .where((user) => user.id.isNotEmpty && !user.isFollowing)
      .toList(growable: false);
  if (needsCheck.isEmpty) return users;

  final confirmedFollowingIds = <String>{};

  // Friends are mutual follows — fastest way to correct Follow back → Following.
  try {
    final friendsResult = await social_di.sl<GetMyFriendsUseCase>()(
      const SocialListQuery(page: 1, limit: 100),
    );
    friendsResult.fold((_) {}, (page) {
      for (final friend in page.users) {
        if (friend.id.isNotEmpty) confirmedFollowingIds.add(friend.id);
      }
    });
  } catch (_) {}

  final stillUnknown = needsCheck
      .where((user) => !confirmedFollowingIds.contains(user.id))
      .toList(growable: false);

  if (stillUnknown.isNotEmpty) {
    final checks = await Future.wait(
      stillUnknown.map((user) async {
        final result = await social_di.sl<CheckIsFollowingUseCase>()(
          CheckIsFollowingParams(
            currentUserId: currentUserId,
            targetUserId: user.id,
          ),
        );
        return result.fold(
          (_) => null,
          (isFollowing) => isFollowing ? user.id : null,
        );
      }),
    );
    for (final id in checks) {
      if (id != null) confirmedFollowingIds.add(id);
    }
  }

  if (confirmedFollowingIds.isEmpty) return users;

  return users
      .map(
        (user) => confirmedFollowingIds.contains(user.id)
            ? user.copyWith(isFollowing: true)
            : user,
      )
      .toList(growable: false);
}
