import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:equatable/equatable.dart';

abstract class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

class InboxLoadRequested extends InboxEvent {
  const InboxLoadRequested({this.refresh = false});

  final bool refresh;

  @override
  List<Object?> get props => [refresh];
}

class InboxSuggestionsLoadRequested extends InboxEvent {
  const InboxSuggestionsLoadRequested({this.limit = 20});

  final int limit;

  @override
  List<Object?> get props => [limit];
}

class InboxChatDismissed extends InboxEvent {
  const InboxChatDismissed({
    required this.chatId,
    this.deleteForEveryone = false,
  });

  final String chatId;
  final bool deleteForEveryone;

  @override
  List<Object?> get props => [chatId, deleteForEveryone];
}

class InboxUserTypingChanged extends InboxEvent {
  const InboxUserTypingChanged({
    required this.chatId,
    required this.isTyping,
  });

  final String chatId;
  final bool isTyping;

  @override
  List<Object?> get props => [chatId, isTyping];
}

class InboxNewMessageReceived extends InboxEvent {
  const InboxNewMessageReceived(this.message);

  final ChatMessageModel message;

  @override
  List<Object?> get props => [message];
}

class InboxChatOpened extends InboxEvent {
  const InboxChatOpened(this.chatId);

  final String chatId;

  @override
  List<Object?> get props => [chatId];
}

