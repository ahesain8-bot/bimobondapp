import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_chats_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_friends_usecase.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_state.dart';
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  InboxBloc({
    required this.getChatsUseCase,
    required this.getFriendsUseCase,
  }) : super(const InboxInitial()) {
    on<InboxLoadRequested>(_onLoadRequested);
    on<InboxFriendsLoadRequested>(_onFriendsLoadRequested);
  }

  final GetChatsUseCase getChatsUseCase;
  final GetFriendsUseCase getFriendsUseCase;

  int _loadGeneration = 0;

  Future<void> _onLoadRequested(
    InboxLoadRequested event,
    Emitter<InboxState> emit,
  ) async {
    if (!event.refresh) emit(const InboxLoading());

    final result = await getChatsUseCase(NoParams());
    final nextGeneration = ++_loadGeneration;
    result.fold(
      (failure) => emit(
        InboxFailure(failure.message, loadGeneration: nextGeneration),
      ),
      (chats) {
        final friends = state is InboxLoadSuccess
            ? (state as InboxLoadSuccess).friends
            : <ChatParticipantEntity>[];
        emit(
          InboxLoadSuccess(
            chats: sortChatsByRecentActivity(chats),
            friends: friends,
            loadGeneration: nextGeneration,
          ),
        );
      },
    );
  }

  Future<void> _onFriendsLoadRequested(
    InboxFriendsLoadRequested event,
    Emitter<InboxState> emit,
  ) async {
    final result = await getFriendsUseCase(
      const SocialListQuery(page: 1, limit: 50),
    );
    result.fold(
      (_) {},
      (friends) {
        if (state is InboxLoadSuccess) {
          final current = state as InboxLoadSuccess;
          emit(
            InboxLoadSuccess(
              chats: current.chats,
              friends: friends,
              loadGeneration: current.loadGeneration,
            ),
          );
        }
      },
    );
  }
}
