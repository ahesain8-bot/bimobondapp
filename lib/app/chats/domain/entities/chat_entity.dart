import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:equatable/equatable.dart';

class ChatEntity extends Equatable {
  const ChatEntity({
    required this.id,
    required this.participants,
    this.name,
    this.isGroup = false,
    this.lastMessage,
    this.unreadCount = 0,
    this.updatedAt,
  });

  final String id;
  final List<ChatParticipantEntity> participants;
  final String? name;
  final bool isGroup;
  final ChatMessageEntity? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  ChatParticipantEntity? otherParticipant(String currentUserId) {
    for (final p in participants) {
      if (p.id != currentUserId) return p;
    }
    return participants.isNotEmpty ? participants.first : null;
  }

  @override
  List<Object?> get props => [
        id,
        participants,
        name,
        isGroup,
        lastMessage,
        unreadCount,
        updatedAt,
      ];
}
