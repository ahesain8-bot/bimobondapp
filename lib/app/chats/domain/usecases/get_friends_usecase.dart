import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetFriendsUseCase
    implements UseCase<List<ChatParticipantEntity>, SocialListQuery> {
  GetFriendsUseCase(this.getMyFriendsUseCase);

  final GetMyFriendsUseCase getMyFriendsUseCase;

  @override
  Future<Either<Failure, List<ChatParticipantEntity>>> call(
    SocialListQuery params,
  ) async {
    final result = await getMyFriendsUseCase(params);
    return result.map(
      (page) => page.users
          .map(
            (user) => ChatParticipantEntity(
              id: user.id,
              username: user.username,
              fullName: user.fullName,
              avatarUrl: user.avatarUrl,
              isActive: user.isActive,
            ),
          )
          .toList(),
    );
  }
}
