import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_chats_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_state.dart';
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  InboxBloc({
    required this.getChatsUseCase,
    required this.getSuggestionsUseCase,
  }) : super(const InboxInitial()) {
    on<InboxLoadRequested>(_onLoadRequested);
    on<InboxSuggestionsLoadRequested>(_onSuggestionsLoadRequested);
  }

  final GetChatsUseCase getChatsUseCase;
  final GetSuggestionsUseCase getSuggestionsUseCase;

  int _loadGeneration = 0;

  InboxLoadSuccess? get _currentSuccess =>
      state is InboxLoadSuccess ? state as InboxLoadSuccess : null;

  void _emitSuccess(
    Emitter<InboxState> emit, {
    List<ChatEntity>? chats,
    List<UserSuggestionEntity>? suggestions,
    int? loadGeneration,
    bool? suggestionsLoaded,
  }) {
    final current = _currentSuccess;
    emit(
      InboxLoadSuccess(
        chats: chats ?? current?.chats ?? const [],
        suggestions: suggestions ?? current?.suggestions ?? const [],
        loadGeneration: loadGeneration ?? current?.loadGeneration ?? 0,
        suggestionsLoaded:
            suggestionsLoaded ?? current?.suggestionsLoaded ?? false,
      ),
    );
  }

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
      (chats) => _emitSuccess(
        emit,
        chats: sortChatsByRecentActivity(chats),
        loadGeneration: nextGeneration,
      ),
    );
  }

  Future<void> _onSuggestionsLoadRequested(
    InboxSuggestionsLoadRequested event,
    Emitter<InboxState> emit,
  ) async {
    final result = await getSuggestionsUseCase(
      GetSuggestionsParams(limit: event.limit),
    );
    result.fold(
      (_) => _emitSuccess(emit, suggestions: const [], suggestionsLoaded: true),
      (suggestions) => _emitSuccess(
        emit,
        suggestions: suggestions.map(UserSuggestionEntity.from).toList(),
        suggestionsLoaded: true,
      ),
    );
  }
}
