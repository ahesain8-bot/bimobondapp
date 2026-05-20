import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.type,
    super.content,
    super.mediaUrl,
    super.replyToId,
    super.sharedPostId,
    super.createdAt,
    super.readByUserIds,
    super.reactions,
    super.isDeleted,
    super.replyPreview,
  });

  static ChatMessageType _parseType(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'TEXT':
        return ChatMessageType.text;
      case 'IMAGE':
        return ChatMessageType.image;
      case 'VIDEO':
        return ChatMessageType.video;
      case 'GIFT':
        return ChatMessageType.gift;
      case 'SHARE':
        return ChatMessageType.share;
      default:
        return ChatMessageType.unknown;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<ChatMessageReactionEntity> _parseReactions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) {
          final map = Map<String, dynamic>.from(e);
          return ChatMessageReactionEntity(
            userId: (map['userId'] ?? map['user_id'] ?? '').toString(),
            emoji: (map['emoji'] ?? '').toString(),
          );
        })
        .where((r) => r.emoji.isNotEmpty)
        .toList();
  }

  static List<String> _parseReadBy(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is Map && raw['userId'] != null) {
      return [raw['userId'].toString()];
    }
    return const [];
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final media = json['mediaUrl'] ?? json['media_url'];
    ChatMessageModel? replyPreview;
    final replyRaw = json['replyTo'] ?? json['reply_to'];
    if (replyRaw is Map) {
      replyPreview = ChatMessageModel.fromJson(
        Map<String, dynamic>.from(replyRaw),
      );
    }

    return ChatMessageModel(
      id: (json['id'] ?? '').toString(),
      chatId: (json['chatId'] ?? json['chat_id'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['sender_id'] ?? json['userId'] ?? '')
          .toString(),
      type: _parseType(json['type']?.toString()),
      content: (json['content'] ?? json['text'] ?? json['message'])?.toString(),
      mediaUrl: media != null
          ? MediaUtils.resolveAbsoluteUrl(media.toString())
          : null,
      replyToId: (json['replyToId'] ?? json['reply_to_id'])?.toString(),
      sharedPostId: (json['sharedPostId'] ?? json['shared_post_id'])?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      readByUserIds: _parseReadBy(json['readBy'] ?? json['read_by']),
      reactions: _parseReactions(json['reactions']),
      isDeleted: json['isDeleted'] == true || json['deleted'] == true,
      replyPreview: replyPreview,
    );
  }
}
