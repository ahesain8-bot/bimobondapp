import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class CreateOrGetChatParams extends Equatable {
  const CreateOrGetChatParams({
    required this.participantIds,
    this.isGroup = false,
    this.name,
  });

  final List<String> participantIds;
  final bool isGroup;
  final String? name;

  @override
  List<Object?> get props => [participantIds, isGroup, name];
}

class CreateOrGetChatUseCase
    implements UseCase<ChatEntity, CreateOrGetChatParams> {
  CreateOrGetChatUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, ChatEntity>> call(CreateOrGetChatParams params) {
    return repository.createOrGetChat(
      participantIds: params.participantIds,
      isGroup: params.isGroup,
      name: params.name,
    );
  }
}
