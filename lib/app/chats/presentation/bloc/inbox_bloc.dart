import 'dart:async';

import 'package:bimobondapp/app/chats/data/datasources/chat_socket_service.dart';
import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_chats_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_state.dart';
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/delete_chat_usecase.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_auth/firebase_auth.dart';

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  InboxBloc({
    required this.getChatsUseCase,
    required this.getSuggestionsUseCase,
    required this.deleteChatUseCase,
    required this.socketService,
  }) : super(const InboxInitial()) {
    on<InboxLoadRequested>(_onLoadRequested);
    on<InboxSuggestionsLoadRequested>(_onSuggestionsLoadRequested);
    on<InboxChatDismissed>(_onChatDismissed);
    on<InboxUserTypingChanged>(_onUserTypingChanged);
    on<InboxNewMessageReceived>(_onNewMessageReceived);
    on<InboxChatOpened>(_onChatOpened);

    socketService.connect();
    _newChatSub = socketService.onNewChat.listen((_) {
      add(const InboxLoadRequested(refresh: true));
    });
    _newMessageSub = socketService.onNewMessage.listen((message) {
      add(InboxNewMessageReceived(message));
    });
    _userTypingSub = socketService.onUserTyping.listen((payload) {
      final chatId =
          payload['chatId']?.toString() ?? payload['chat_id']?.toString();
      if (chatId != null && chatId.isNotEmpty) {
        final isTyping =
            payload['isTyping'] == true || payload['is_typing'] == true;
        add(InboxUserTypingChanged(chatId: chatId, isTyping: isTyping));
      }
    });
  }

  final GetChatsUseCase getChatsUseCase;
  final GetSuggestionsUseCase getSuggestionsUseCase;
  final DeleteChatUseCase deleteChatUseCase;
  final ChatSocketService socketService;

  StreamSubscription<Map<String, dynamic>>? _newChatSub;
  StreamSubscription<ChatMessageModel>? _newMessageSub;
  StreamSubscription<Map<String, dynamic>>? _userTypingSub;

  @override
  Future<void> close() {
    _newChatSub?.cancel();
    _newMessageSub?.cancel();
    _userTypingSub?.cancel();
    return super.close();
  }

  void _onNewMessageReceived(
    InboxNewMessageReceived event,
    Emitter<InboxState> emit,
  ) {
    final current = _currentSuccess;
    final message = event.message;
    final chatId = message.chatId;

    if (current != null && chatId.isNotEmpty) {
      final existingIndex = current.chats.indexWhere((c) => c.id == chatId);
      if (existingIndex != -1) {
        final existingChat = current.chats[existingIndex];
        final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final isFromMe =
            message.senderId.isNotEmpty && message.senderId == myId;

        final newUnreadCount = isFromMe
            ? 0
            : (existingChat.unreadCount > 0 ? existingChat.unreadCount + 1 : 1);

        final updatedChat = existingChat.copyWith(
          lastMessage: message,
          unreadCount: newUnreadCount,
          updatedAt: message.createdAt ?? DateTime.now(),
        );

        final updatedList = List<ChatEntity>.from(current.chats);
        updatedList[existingIndex] = updatedChat;

        _emitSuccess(
          emit,
          chats: sortChatsByRecentActivity(updatedList),
        );
      }
    }
    add(const InboxLoadRequested(refresh: true));
  }

  void _onChatOpened(
    InboxChatOpened event,
    Emitter<InboxState> emit,
  ) {
    final current = _currentSuccess;
    if (current == null) return;

    final existingIndex = current.chats.indexWhere((c) => c.id == event.chatId);
    if (existingIndex != -1) {
      final existingChat = current.chats[existingIndex];
      if (existingChat.unreadCount > 0) {
        final updatedChat = existingChat.copyWith(unreadCount: 0);
        final updatedList = List<ChatEntity>.from(current.chats);
        updatedList[existingIndex] = updatedChat;
        _emitSuccess(emit, chats: updatedList);
      }
    }
  }

  void _onUserTypingChanged(
    InboxUserTypingChanged event,
    Emitter<InboxState> emit,
  ) {
    final current = _currentSuccess;
    if (current == null) return;
    final Map<String, bool> updatedTyping = Map.from(current.typingChatIds);
    if (event.isTyping) {
      updatedTyping[event.chatId] = true;
    } else {
      updatedTyping.remove(event.chatId);
    }
    emit(current.copyWith(typingChatIds: updatedTyping));
  }

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

    final currentSuccess = _currentSuccess;
    final result = await getChatsUseCase(NoParams());
    final nextGeneration = ++_loadGeneration;

    result.fold(
      (failure) => emit(
        InboxFailure(failure.message, loadGeneration: nextGeneration),
      ),
      (fetchedChats) {
        final List<ChatEntity> mergedChats = [];
        if (currentSuccess != null) {
          final localUnreadMap = <String, int>{};
          for (final c in currentSuccess.chats) {
            if (c.unreadCount > 0) {
              localUnreadMap[c.id] = c.unreadCount;
            }
          }
          for (final chat in fetchedChats) {
            final localUnread = localUnreadMap[chat.id];
            if (localUnread != null && localUnread > chat.unreadCount) {
              mergedChats.add(chat.copyWith(unreadCount: localUnread));
            } else {
              mergedChats.add(chat);
            }
          }
        } else {
          mergedChats.addAll(fetchedChats);
        }

        _emitSuccess(
          emit,
          chats: sortChatsByRecentActivity(mergedChats),
          loadGeneration: nextGeneration,
        );
      },
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

  Future<void> _onChatDismissed(
    InboxChatDismissed event,
    Emitter<InboxState> emit,
  ) async {
    final current = _currentSuccess;
    if (current == null) return;

    final updatedChats = current.chats
        .where((chat) => chat.id != event.chatId)
        .toList();

    _emitSuccess(emit, chats: updatedChats);

    if (!event.chatId.startsWith('mock-')) {
      final result = await deleteChatUseCase(DeleteChatParams(
        chatId: event.chatId,
        deleteForEveryone: event.deleteForEveryone,
      ));
      result.fold(
        (failure) {
          add(const InboxLoadRequested(refresh: true));
        },
        (_) => null,
      );
    }
  }
}
