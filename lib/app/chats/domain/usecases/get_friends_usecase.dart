import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetFriendsUseCase
    implements UseCase<List<ChatParticipantEntity>, NoParams> {
  GetFriendsUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, List<ChatParticipantEntity>>> call(NoParams params) {
    return repository.getFriends();
  }
}
