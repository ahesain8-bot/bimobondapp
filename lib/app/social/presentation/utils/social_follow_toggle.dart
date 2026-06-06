import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/core/error/failures.dart';

/// Toggles follow for a user. Returns the resolved follow state, or a failure.
Future<({bool? isFollowing, Failure? failure})> toggleSocialUserFollow({
  required String userId,
  required bool wasFollowing,
}) async {
  final result = await social_di.sl<ToggleFollowUseCase>()(
    ToggleFollowParams(userId),
  );

  return result.fold(
    (failure) => (isFollowing: null, failure: failure),
    (status) => (
      isFollowing: FollowStatus.resolveIsFollowing(
        wasFollowing: wasFollowing,
        status: status,
      ),
      failure: null,
    ),
  );
}
