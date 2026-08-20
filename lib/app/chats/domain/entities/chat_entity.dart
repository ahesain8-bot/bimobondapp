import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:equatable/equatable.dart';

class ChatEntity extends Equatable {
  const ChatEntity({
    required this.id,
    required this.participants,
    this.name,
    this.isGroup = false,
    this.isPinned = false,
    this.isMuted = false,
    this.lastMessage,
    this.unreadCount = 0,
    this.updatedAt,
  });

  final String id;
  final List<ChatParticipantEntity> participants;
  final String? name;
  final bool isGroup;
  final bool isPinned;
  final bool isMuted;
  final ChatMessageEntity? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  ChatEntity copyWith({
    String? id,
    List<ChatParticipantEntity>? participants,
    String? name,
    bool? isGroup,
    bool? isPinned,
    bool? isMuted,
    ChatMessageEntity? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      name: name ?? this.name,
      isGroup: isGroup ?? this.isGroup,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
        isPinned,
        isMuted,
        lastMessage,
        unreadCount,
        updatedAt,
      ];
}
