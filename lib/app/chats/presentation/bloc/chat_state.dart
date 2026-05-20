import 'package:equatable/equatable.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoadSuccess extends ChatState {
  const ChatLoadSuccess({
    required this.messages,
    required this.currentUserId,
    this.isTypingRemote = false,
    this.hasReachedMax = false,
    this.isSending = false,
  });

  final List<Map<String, dynamic>> messages;
  final String currentUserId;
  final bool isTypingRemote;
  final bool hasReachedMax;
  final bool isSending;

  ChatLoadSuccess copyWith({
    List<Map<String, dynamic>>? messages,
    bool? isTypingRemote,
    bool? hasReachedMax,
    bool? isSending,
  }) {
    return ChatLoadSuccess(
      messages: messages ?? this.messages,
      currentUserId: currentUserId,
      isTypingRemote: isTypingRemote ?? this.isTypingRemote,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isSending: isSending ?? this.isSending,
    );
  }

  @override
  List<Object?> get props =>
      [messages, currentUserId, isTypingRemote, hasReachedMax, isSending];
}

class ChatFailure extends ChatState {
  const ChatFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
