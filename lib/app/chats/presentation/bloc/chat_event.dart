import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  const ChatStarted({required this.chatId, required this.currentUserId});

  final String chatId;
  final String currentUserId;

  @override
  List<Object?> get props => [chatId, currentUserId];
}

class ChatMessagesLoadRequested extends ChatEvent {
  const ChatMessagesLoadRequested({this.page = 1, this.refresh = false});

  final int page;
  final bool refresh;

  @override
  List<Object?> get props => [page, refresh];
}

class ChatMessageSendRequested extends ChatEvent {
  const ChatMessageSendRequested({
    required this.content,
    this.replyToId,
    this.sharedPostId,
  });

  final String content;
  final String? replyToId;
  final String? sharedPostId;

  @override
  List<Object?> get props => [content, replyToId, sharedPostId];
}

class ChatAttachmentSendRequested extends ChatEvent {
  const ChatAttachmentSendRequested({
    required this.messageType,
    this.content = '',
    this.localFilePath,
    this.replyToId,
    this.payload,
    this.mimeType,
    this.sizeBytes,
  });

  final String messageType;
  final String content;
  final String? localFilePath;
  final String? replyToId;
  final Map<String, dynamic>? payload;
  final String? mimeType;
  final int? sizeBytes;

  @override
  List<Object?> get props => [
    messageType,
    content,
    localFilePath,
    replyToId,
    payload,
    mimeType,
    sizeBytes,
  ];
}

class ChatPollVoteRequested extends ChatEvent {
  const ChatPollVoteRequested({
    required this.messageId,
    required this.optionIndex,
  });

  final String messageId;
  final int optionIndex;

  @override
  List<Object?> get props => [messageId, optionIndex];
}

class ChatVoiceMessageSendRequested extends ChatEvent {
  const ChatVoiceMessageSendRequested({
    required this.filePath,
    required this.durationSeconds,
    this.replyToId,
  });

  final String filePath;
  final int durationSeconds;
  final String? replyToId;

  @override
  List<Object?> get props => [filePath, durationSeconds, replyToId];
}

class ChatMessageReactRequested extends ChatEvent {
  const ChatMessageReactRequested({
    required this.messageId,
    required this.emoji,
  });

  final String messageId;
  final String emoji;

  @override
  List<Object?> get props => [messageId, emoji];
}

class ChatMessageDeleteRequested extends ChatEvent {
  const ChatMessageDeleteRequested({required this.messageId});

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

class ChatTypingChanged extends ChatEvent {
  const ChatTypingChanged({required this.isTyping});

  final bool isTyping;

  @override
  List<Object?> get props => [isTyping];
}

class ChatStopped extends ChatEvent {
  const ChatStopped();
}

class ChatSocketMessageReceived extends ChatEvent {
  const ChatSocketMessageReceived(this.raw);

  final Map<String, dynamic> raw;

  @override
  List<Object?> get props => [raw];
}

class ChatSocketUserTyping extends ChatEvent {
  const ChatSocketUserTyping({required this.userId, required this.isTyping});

  final String userId;
  final bool isTyping;

  @override
  List<Object?> get props => [userId, isTyping];
}

class ChatSocketMessageRead extends ChatEvent {
  const ChatSocketMessageRead(this.payload);

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [payload];
}

class ChatSocketMessageReacted extends ChatEvent {
  const ChatSocketMessageReacted(this.payload);

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [payload];
}

class ChatSocketMessageDeleted extends ChatEvent {
  const ChatSocketMessageDeleted(this.payload);

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [payload];
}
