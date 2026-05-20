import 'package:equatable/equatable.dart';

enum ChatMessageType { text, image, video, gift, share, unknown }

class ChatMessageReactionEntity extends Equatable {
  const ChatMessageReactionEntity({
    required this.userId,
    required this.emoji,
  });

  final String userId;
  final String emoji;

  @override
  List<Object?> get props => [userId, emoji];
}

class ChatMessageEntity extends Equatable {
  const ChatMessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.replyToId,
    this.sharedPostId,
    this.createdAt,
    this.readByUserIds = const [],
    this.reactions = const [],
    this.isDeleted = false,
    this.replyPreview,
  });

  final String id;
  final String chatId;
  final String senderId;
  final ChatMessageType type;
  final String? content;
  final String? mediaUrl;
  final String? replyToId;
  final String? sharedPostId;
  final DateTime? createdAt;
  final List<String> readByUserIds;
  final List<ChatMessageReactionEntity> reactions;
  final bool isDeleted;
  final ChatMessageEntity? replyPreview;

  bool isReadBy(String userId) => readByUserIds.contains(userId);

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        type,
        content,
        mediaUrl,
        replyToId,
        sharedPostId,
        createdAt,
        readByUserIds,
        reactions,
        isDeleted,
        replyPreview,
      ];
}
