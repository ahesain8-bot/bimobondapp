import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  const ChatStarted({
    required this.chatId,
    required this.currentUserId,
  });

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
  });

  final String content;
  final String? replyToId;

  @override
  List<Object?> get props => [content, replyToId];
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
  const ChatSocketUserTyping({
    required this.userId,
    required this.isTyping,
  });

  final String userId;
  final bool isTyping;

  @override
  List<Object?> get props => [userId, isTyping];
}
