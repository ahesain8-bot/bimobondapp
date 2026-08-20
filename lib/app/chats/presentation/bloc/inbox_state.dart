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
    this.typingChatIds = const {},
  });

  final List<ChatEntity> chats;
  final List<UserSuggestionEntity> suggestions;

  /// Bumped after each inbox fetch so pull-to-refresh can detect completion.
  final int loadGeneration;
  final bool suggestionsLoaded;
  final Map<String, bool> typingChatIds;

  InboxLoadSuccess copyWith({
    List<ChatEntity>? chats,
    List<UserSuggestionEntity>? suggestions,
    int? loadGeneration,
    bool? suggestionsLoaded,
    Map<String, bool>? typingChatIds,
  }) {
    return InboxLoadSuccess(
      chats: chats ?? this.chats,
      suggestions: suggestions ?? this.suggestions,
      loadGeneration: loadGeneration ?? this.loadGeneration,
      suggestionsLoaded: suggestionsLoaded ?? this.suggestionsLoaded,
      typingChatIds: typingChatIds ?? this.typingChatIds,
    );
  }

  @override
  List<Object?> get props => [
        chats,
        suggestions,
        loadGeneration,
        suggestionsLoaded,
        typingChatIds,
      ];
}

class InboxFailure extends InboxState {
  const InboxFailure(this.message, {this.loadGeneration = 0});

  final String message;
  final int loadGeneration;

  @override
  List<Object?> get props => [message, loadGeneration];
}
