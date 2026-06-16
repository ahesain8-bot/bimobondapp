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

