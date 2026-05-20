import 'dart:async';

import 'package:bimobondapp/app/chats/data/datasources/chat_socket_service.dart';
import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_chat_messages_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/mark_message_read_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/react_to_message_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/send_message_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_state.dart';
import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this.getChatMessagesUseCase,
    required this.sendMessageUseCase,
    required this.reactToMessageUseCase,
    required this.markMessageReadUseCase,
    required this.socketService,
  }) : super(const ChatInitial()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessagesLoadRequested>(_onMessagesLoadRequested);
    on<ChatMessageSendRequested>(_onMessageSendRequested);
    on<ChatMessageReactRequested>(_onMessageReactRequested);
    on<ChatTypingChanged>(_onTypingChanged);
    on<ChatStopped>(_onStopped);
    on<ChatSocketMessageReceived>(_onSocketMessage);
    on<ChatSocketUserTyping>(_onSocketUserTyping);
  }

  final GetChatMessagesUseCase getChatMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;
  final ReactToMessageUseCase reactToMessageUseCase;
  final MarkMessageReadUseCase markMessageReadUseCase;
  final ChatSocketService socketService;

  String? _chatId;
  String? _currentUserId;
  StreamSubscription<ChatMessageModel>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _readSub;
  StreamSubscription<Map<String, dynamic>>? _reactedSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    _chatId = event.chatId;
    _currentUserId = event.currentUserId;

    await socketService.connect();
    socketService.joinChat(event.chatId);

    _messageSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _reactedSub?.cancel();
    _deletedSub?.cancel();

    _messageSub = socketService.onNewMessage.listen((message) {
      if (message.chatId != _chatId) return;
      add(ChatSocketMessageReceived(chatMessageToUiMap(message, event.currentUserId)));
    });

    _typingSub = socketService.onUserTyping.listen((payload) {
      final chatId = payload['chatId']?.toString();
      if (chatId != _chatId) return;
      add(
        ChatSocketUserTyping(
          userId: payload['userId']?.toString() ?? '',
          isTyping: payload['isTyping'] == true,
        ),
      );
    });

    _readSub = socketService.onMessageRead.listen((payload) {
      _applyReadReceipt(payload, emit);
    });

    _reactedSub = socketService.onMessageReacted.listen((payload) {
      _applyReaction(payload, emit);
    });

    _deletedSub = socketService.onMessageDeleted.listen((payload) {
      _applyDeleted(payload, emit);
    });

    add(const ChatMessagesLoadRequested(refresh: true));
  }

  Future<void> _onMessagesLoadRequested(
    ChatMessagesLoadRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = _chatId;
    final userId = _currentUserId;
    if (chatId == null || userId == null) return;

    if (event.refresh || event.page == 1) {
      emit(const ChatLoading());
    }

    const limit = 20;
    final result = await getChatMessagesUseCase(
      GetChatMessagesParams(chatId: chatId, page: event.page, limit: limit),
    );

    result.fold(
      (failure) => emit(ChatFailure(failure.message)),
      (messages) {
        final uiMessages = chatMessagesToUiMaps(messages, userId);
        final hasReachedMax = messages.length < limit;

        if (state is ChatLoadSuccess && event.page > 1 && !event.refresh) {
          final current = state as ChatLoadSuccess;
          final existingIds = current.messages.map((m) => m['id']).toSet();
          final merged = sortChatMessagesOldestFirst([
            ...uiMessages.where((m) => !existingIds.contains(m['id'])),
            ...current.messages,
          ]);
          emit(current.copyWith(messages: merged, hasReachedMax: hasReachedMax));
        } else {
          emit(
            ChatLoadSuccess(
              messages: uiMessages,
              currentUserId: userId,
              hasReachedMax: hasReachedMax,
            ),
          );
        }

        for (final msg in messages) {
          if (msg.senderId != userId && !msg.isReadBy(userId)) {
            markMessageReadUseCase(MarkMessageReadParams(messageId: msg.id));
          }
        }
      },
    );
  }

  Future<void> _onMessageSendRequested(
    ChatMessageSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = _chatId;
    final userId = _currentUserId;
    if (chatId == null || userId == null) return;
    if (state is! ChatLoadSuccess) return;

    final current = state as ChatLoadSuccess;
    emit(current.copyWith(isSending: true));

    final result = await sendMessageUseCase(
      SendMessageParams(
        chatId: chatId,
        content: event.content,
        replyToId: event.replyToId,
      ),
    );

    result.fold(
      (failure) => emit(ChatFailure(failure.message)),
      (message) {
        final ui = chatMessageToUiMap(message, userId);
        final ids = current.messages.map((m) => m['id']).toSet();
        if (ids.contains(ui['id'])) {
          emit(current.copyWith(isSending: false));
          return;
        }
        emit(
          current.copyWith(
            messages: sortChatMessagesOldestFirst([...current.messages, ui]),
            isSending: false,
          ),
        );
      },
    );
  }

  Future<void> _onMessageReactRequested(
    ChatMessageReactRequested event,
    Emitter<ChatState> emit,
  ) async {
    await reactToMessageUseCase(
      ReactToMessageParams(
        messageId: event.messageId,
        emoji: event.emoji,
      ),
    );
  }

  void _onTypingChanged(ChatTypingChanged event, Emitter<ChatState> emit) {
    final chatId = _chatId;
    final userId = _currentUserId;
    if (chatId == null || userId == null) return;
    socketService.sendTyping(
      chatId: chatId,
      userId: userId,
      isTyping: event.isTyping,
    );
  }

  void _onSocketMessage(ChatSocketMessageReceived event, Emitter<ChatState> emit) {
    if (state is! ChatLoadSuccess) return;
    final current = state as ChatLoadSuccess;
    final id = event.raw['id'];
    if (current.messages.any((m) => m['id'] == id)) return;
    emit(
      current.copyWith(
        messages: sortChatMessagesOldestFirst([...current.messages, event.raw]),
      ),
    );

    final senderId = event.raw['senderId']?.toString();
    if (senderId != null &&
        senderId != _currentUserId &&
        id != null) {
      markMessageReadUseCase(MarkMessageReadParams(messageId: id.toString()));
    }
  }

  void _onSocketUserTyping(ChatSocketUserTyping event, Emitter<ChatState> emit) {
    if (event.userId == _currentUserId) return;
    if (state is! ChatLoadSuccess) return;
    final current = state as ChatLoadSuccess;
    emit(current.copyWith(isTypingRemote: event.isTyping));
  }

  void _applyReadReceipt(Map<String, dynamic> payload, Emitter<ChatState> emit) {
    if (state is! ChatLoadSuccess) return;
    final messageId = payload['messageId']?.toString();
    if (messageId == null) return;

    final current = state as ChatLoadSuccess;
    final updated = current.messages.map((m) {
      if (m['id'] == messageId && m['isMe'] == true) {
        return {...m, 'status': 'read'};
      }
      return m;
    }).toList();
    emit(current.copyWith(messages: updated));
  }

  void _applyReaction(Map<String, dynamic> payload, Emitter<ChatState> emit) {
    if (state is! ChatLoadSuccess) return;
    final messageId = payload['messageId']?.toString();
    final emoji = payload['emoji']?.toString();
    if (messageId == null || emoji == null) return;

    final current = state as ChatLoadSuccess;
    final updated = current.messages.map((m) {
      if (m['id'] == messageId) {
        return {...m, 'reactions': [emoji]};
      }
      return m;
    }).toList();
    emit(current.copyWith(messages: updated));
  }

  void _applyDeleted(Map<String, dynamic> payload, Emitter<ChatState> emit) {
    if (state is! ChatLoadSuccess) return;
    final messageId = payload['messageId']?.toString();
    if (messageId == null) return;

    final current = state as ChatLoadSuccess;
    final updated = current.messages.map((m) {
      if (m['id'] == messageId) {
        return {
          ...m,
          'text': 'This message was deleted',
          'type': 'text',
        };
      }
      return m;
    }).toList();
    emit(current.copyWith(messages: updated));
  }

  Future<void> _onStopped(ChatStopped event, Emitter<ChatState> emit) async {
    final chatId = _chatId;
    if (chatId != null) {
      socketService.leaveChat(chatId);
    }
    await _messageSub?.cancel();
    await _typingSub?.cancel();
    await _readSub?.cancel();
    await _reactedSub?.cancel();
    await _deletedSub?.cancel();
    _messageSub = null;
    _typingSub = null;
    _readSub = null;
    _reactedSub = null;
    _deletedSub = null;
  }

  @override
  Future<void> close() async {
    add(const ChatStopped());
    return super.close();
  }
}
