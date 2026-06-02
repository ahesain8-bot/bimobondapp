import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:equatable/equatable.dart';

abstract class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {
  const InboxInitial();
}

class InboxLoading extends InboxState {
  const InboxLoading();
}

class InboxLoadSuccess extends InboxState {
  const InboxLoadSuccess({
    required this.chats,
    this.suggestions = const [],
    this.loadGeneration = 0,
    this.suggestionsLoaded = false,
  });

  final List<ChatEntity> chats;
  final List<UserSuggestionEntity> suggestions;

  /// Bumped after each inbox fetch so pull-to-refresh can detect completion.
  final int loadGeneration;
  final bool suggestionsLoaded;

  @override
  List<Object?> get props => [
        chats,
        suggestions,
        loadGeneration,
        suggestionsLoaded,
      ];
}

class InboxFailure extends InboxState {
  const InboxFailure(this.message, {this.loadGeneration = 0});

  final String message;
  final int loadGeneration;

  @override
  List<Object?> get props => [message, loadGeneration];
}
