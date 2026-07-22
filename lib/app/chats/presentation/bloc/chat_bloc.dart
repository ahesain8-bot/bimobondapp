import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/chats/data/datasources/chat_socket_service.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_chat_messages_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/delete_message_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/mark_message_read_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/react_to_message_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/send_message_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/vote_poll_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_event.dart';
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_state.dart';
import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/chats/presentation/utils/chat_send_content.dart';
import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this.getChatMessagesUseCase,
    required this.sendMessageUseCase,
    required this.votePollUseCase,
    required this.uploadMediaUseCase,
    required this.reactToMessageUseCase,
    required this.markMessageReadUseCase,
    required this.deleteMessageUseCase,
    required this.socketService,
  }) : super(const ChatInitial()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessagesLoadRequested>(_onMessagesLoadRequested);
    on<ChatMessageSendRequested>(_onMessageSendRequested);
    on<ChatVoiceMessageSendRequested>(_onVoiceMessageSendRequested);
    on<ChatAttachmentSendRequested>(_onAttachmentSendRequested);
    on<ChatPollVoteRequested>(_onPollVoteRequested);
    on<ChatMessageReactRequested>(_onMessageReactRequested);
    on<ChatMessageDeleteRequested>(_onMessageDeleteRequested);
    on<ChatTypingChanged>(_onTypingChanged);
    on<ChatStopped>(_onStopped);
    on<ChatSocketMessageReceived>(_onSocketMessage);
    on<ChatSocketUserTyping>(_onSocketUserTyping);
    on<ChatSocketMessageRead>(_onSocketMessageRead);
    on<ChatSocketMessageReacted>(_onSocketMessageReacted);
    on<ChatSocketMessageDeleted>(_onSocketMessageDeleted);
  }

  final GetChatMessagesUseCase getChatMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;
  final VotePollUseCase votePollUseCase;
  final UploadMediaUseCase uploadMediaUseCase;
  final ReactToMessageUseCase reactToMessageUseCase;
  final MarkMessageReadUseCase markMessageReadUseCase;
  final DeleteMessageUseCase deleteMessageUseCase;
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
    socketService.joinChat(event.chatId, userId: event.currentUserId);

    _messageSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _reactedSub?.cancel();
    _deletedSub?.cancel();

    _messageSub = socketService.onNewMessage.listen((message) {
      if (message.chatId != _chatId) return;
      add(
        ChatSocketMessageReceived(
          chatMessageToUiMap(message, event.currentUserId),
        ),
      );
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
      add(ChatSocketMessageRead(Map<String, dynamic>.from(payload)));
    });

    _reactedSub = socketService.onMessageReacted.listen((payload) {
      add(ChatSocketMessageReacted(Map<String, dynamic>.from(payload)));
    });

    _deletedSub = socketService.onMessageDeleted.listen((payload) {
      add(ChatSocketMessageDeleted(Map<String, dynamic>.from(payload)));
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

    result.fold((failure) => emit(ChatFailure(failure.message)), (messages) {
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
        if (!msg.isDeleted && msg.senderId != userId && !msg.isReadBy(userId)) {
          unawaited(
            markMessageReadUseCase(MarkMessageReadParams(messageId: msg.id)),
          );
        }
      }
    });
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
        sharedPostId: event.sharedPostId,
      ),
    );

    result.fold((failure) => emit(ChatFailure(failure.message)), (message) {
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
    });
  }

  Future<void> _onVoiceMessageSendRequested(
    ChatVoiceMessageSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = _chatId;
    final userId = _currentUserId;
    if (chatId == null || userId == null) return;
    if (state is! ChatLoadSuccess) return;

    final current = state as ChatLoadSuccess;
    emit(current.copyWith(isSending: true));

    final file = File(event.filePath);
    final uploadResult = await uploadMediaUseCase(file);
    if (await file.exists()) {
      await file.delete();
    }

    await uploadResult.fold(
      (failure) async {
        emit(ChatFailure(failure.message));
      },
      (mediaUrl) async {
        final sendResult = await sendMessageUseCase(
          SendMessageParams(
            chatId: chatId,
            content: event.durationSeconds.toString(),
            type: 'AUDIO',
            mediaUrl: mediaUrl,
            replyToId: event.replyToId,
          ),
        );

        sendResult.fold((failure) => emit(ChatFailure(failure.message)), (
          message,
        ) {
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
        });
      },
    );
  }

  Future<void> _onAttachmentSendRequested(
    ChatAttachmentSendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = _chatId;
    final userId = _currentUserId;
    if (chatId == null || userId == null) return;
    if (state is! ChatLoadSuccess) return;

    final current = state as ChatLoadSuccess;
    emit(current.copyWith(isSending: true));

    Future<void> sendWithMediaUrl(String? mediaUrl) async {
      final content = buildChatMessageContent(
        messageType: event.messageType,
        draftContent: event.content,
        mediaUrl: mediaUrl,
      );

      Map<String, dynamic>? payload = event.payload;
      String? outgoingMediaUrl = mediaUrl;

      if (event.messageType.toUpperCase() == 'FILE' &&
          mediaUrl != null &&
          mediaUrl.trim().isNotEmpty) {
        final fileName = event.content.trim().isNotEmpty
            ? event.content.trim()
            : (event.localFilePath?.split(RegExp(r'[/\\]')).last ?? 'file');
        final mime = event.mimeType?.trim().isNotEmpty == true
            ? event.mimeType!
            : inferMimeTypeFromFileName(fileName);
        payload = ChatFilePayload(
          url: mediaUrl,
          fileName: fileName,
          mimeType: mime,
          sizeBytes: event.sizeBytes,
        ).toPayloadMap();
        outgoingMediaUrl = mediaUrl;
      }

      final sendResult = await sendMessageUseCase(
        SendMessageParams(
          chatId: chatId,
          content: content,
          type: event.messageType,
          mediaUrl: outgoingMediaUrl,
          replyToId: event.replyToId,
          payload: payload,
        ),
      );

      sendResult.fold(
        (failure) => emit(ChatFailure(failure.message)),
        (message) => _emitSentMessage(emit, current, message, userId),
      );
    }

    final filePath = event.localFilePath;
    final needsUpload = chatMessageTypeRequiresUpload(event.messageType);

    if (!needsUpload || filePath == null || filePath.isEmpty) {
      await sendWithMediaUrl(null);
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      final fileName = filePath.split(RegExp(r'[/\\]')).last;
      emit(ChatFailure('Cannot read "$fileName".'));
      return;
    }

    final uploadResult = await uploadMediaUseCase(file);
    await uploadResult.fold(
      (failure) async {
        emit(ChatFailure(failure.message));
      },
      (mediaUrl) async {
        if (mediaUrl.trim().isEmpty) {
          emit(ChatFailure('Upload did not return a media URL.'));
          return;
        }
        await sendWithMediaUrl(mediaUrl);
      },
    );
  }

  Future<void> _onPollVoteRequested(
    ChatPollVoteRequested event,
    Emitter<ChatState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;
    if (state is! ChatLoadSuccess) return;
    final current = state as ChatLoadSuccess;

    final result = await votePollUseCase(
      VotePollParams(
        messageId: event.messageId,
        optionIndex: event.optionIndex,
      ),
    );

    result.fold((failure) => emit(ChatFailure(failure.message)), (message) {
      final ui = chatMessageToUiMap(message, userId);
      final updated = current.messages.map((m) {
        if (m['id'] == ui['id']) return ui;
        return m;
      }).toList();
      emit(current.copyWith(messages: updated));
    });
  }

  void _emitSentMessage(
    Emitter<ChatState> emit,
    ChatLoadSuccess current,
    ChatMessageEntity message,
    String userId,
  ) {
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
  }

  Future<void> _onMessageReactRequested(
    ChatMessageReactRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatLoadSuccess) return;
    final current = state as ChatLoadSuccess;

    emit(
      current.copyWith(
        messages: _messagesWithReaction(
          current.messages,
          event.messageId,
          event.emoji,
        ),
      ),
    );

    final result = await reactToMessageUseCase(
      ReactToMessageParams(messageId: event.messageId, emoji: event.emoji),
    );

    result.fold((failure) {
      if (!emit.isDone) emit(ChatFailure(failure.message));
    }, (_) {});
  }

  Future<void> _onMessageDeleteRequested(
    ChatMessageDeleteRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatLoadSuccess) return;
    final current = state as ChatLoadSuccess;

    emit(
      current.copyWith(
        messages: _messagesMarkedDeleted(current.messages, event.messageId),
      ),
    );

    final result = await deleteMessageUseCase(
      DeleteMessageParams(messageId: event.messageId),
    );

    result.fold((failure) => emit(ChatFailure(failure.message)), (_) {});
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

  void _onSocketMessage(
    ChatSocketMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    if (state is! ChatLoadSuccess) return;
    final current = state as ChatLoadSuccess;
    final id = event.raw['id'];
    final existingIndex = current.messages.indexWhere((m) => m['id'] == id);
    if (existingIndex >= 0) {
      final updated = List<Map<String, dynamic>>.from(current.messages);
      updated[existingIndex] = event.raw;
      emit(current.copyWith(messages: updated));
      return;
    }
    emit(
      current.copyWith(
        messages: sortChatMessagesOldestFirst([...current.messages, event.raw]),
      ),
    );

    final senderId = event.raw['senderId']?.toString();
    if (senderId != null &&
        senderId != _currentUserId &&
        id != null &&
        event.raw['isDeleted'] != true) {
      unawaited(
        markMessageReadUseCase(MarkMessageReadParams(messageId: id.toString())),
      );
    }
  }

  void _onSocketUserTyping(
    ChatSocketUserTyping event,
    Emitter<ChatState> emit,
  ) {
    if (event.userId == _currentUserId) return;
    if (state is! ChatLoadSuccess) return;
    final current = state as ChatLoadSuccess;
    emit(current.copyWith(isTypingRemote: event.isTyping));
  }

  String? _messageIdFromPayload(Map<String, dynamic> payload) {
    return payload['messageId']?.toString() ?? payload['id']?.toString();
  }

  List<Map<String, dynamic>> _messagesWithReaction(
    List<Map<String, dynamic>> messages,
    String messageId,
    String emoji,
  ) {
    return messages.map((m) {
      if (m['id'] == messageId) {
        return {
          ...m,
          'reactions': [emoji],
        };
      }
      return m;
    }).toList();
  }

  List<Map<String, dynamic>> _messagesMarkedDeleted(
    List<Map<String, dynamic>> messages,
    String messageId,
  ) {
    return messages.map((m) {
      if (m['id'] == messageId) {
        return {
          ...m,
          'isDeleted': true,
          'type': 'text',
          'text': '',
          'textKey': 'deleted',
        };
      }
      return m;
    }).toList();
  }

  void _onSocketMessageRead(
    ChatSocketMessageRead event,
    Emitter<ChatState> emit,
  ) {
    if (state is! ChatLoadSuccess) return;
    final messageId = _messageIdFromPayload(event.payload);
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

  void _onSocketMessageReacted(
    ChatSocketMessageReacted event,
    Emitter<ChatState> emit,
  ) {
    if (state is! ChatLoadSuccess) return;
    final messageId = _messageIdFromPayload(event.payload);
    final emoji = event.payload['emoji']?.toString();
    if (messageId == null || emoji == null) return;

    final current = state as ChatLoadSuccess;
    emit(
      current.copyWith(
        messages: _messagesWithReaction(current.messages, messageId, emoji),
      ),
    );
  }

  void _onSocketMessageDeleted(
    ChatSocketMessageDeleted event,
    Emitter<ChatState> emit,
  ) {
    if (state is! ChatLoadSuccess) return;
    final messageId = _messageIdFromPayload(event.payload);
    if (messageId == null) return;

    final current = state as ChatLoadSuccess;
    emit(
      current.copyWith(
        messages: _messagesMarkedDeleted(current.messages, messageId),
      ),
    );
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
