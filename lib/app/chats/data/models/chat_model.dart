import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/data/models/chat_participant_model.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';

class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.participants,
    super.name,
    super.isGroup,
    super.lastMessage,
    super.unreadCount,
    super.updatedAt,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final participantsRaw =
        json['participants'] ?? json['members'] ?? json['users'];
    final participants = participantsRaw is List
        ? participantsRaw
            .whereType<Map>()
            .map(
              (e) => ChatParticipantModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <ChatParticipantModel>[];

    final chatId = (json['id'] ?? '').toString();
    final lastMessage = _parseLastMessage(json, chatId);

    return ChatModel(
      id: chatId,
      participants: participants,
      name: json['name']?.toString(),
      isGroup: json['isGroup'] == true || json['is_group'] == true,
      lastMessage: lastMessage,
      unreadCount:
          ((json['unreadCount'] ?? json['unread_count']) as num?)?.toInt() ?? 0,
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static ChatMessageModel? _parseLastMessage(
    Map<String, dynamic> json,
    String chatId,
  ) {
    final lastRaw = json['lastMessage'] ??
        json['last_message'] ??
        json['latestMessage'] ??
        json['latest_message'];

    if (lastRaw is Map) {
      return ChatMessageModel.fromJson(Map<String, dynamic>.from(lastRaw));
    }

    if (lastRaw is String && lastRaw.trim().isNotEmpty) {
      return _syntheticLastMessage(
        json: json,
        chatId: chatId,
        content: lastRaw.trim(),
      );
    }

    final textOnly = json['lastMessageText'] ??
        json['last_message_text'] ??
        json['lastMessageContent'] ??
        json['last_message_content'] ??
        json['preview'] ??
        json['snippet'];
    if (textOnly != null && textOnly.toString().trim().isNotEmpty) {
      return _syntheticLastMessage(
        json: json,
        chatId: chatId,
        content: textOnly.toString().trim(),
      );
    }

    final messages = json['messages'];
    if (messages is List && messages.isNotEmpty) {
      Map<String, dynamic>? latest;
      DateTime? latestAt;
      for (final item in messages) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final at = _parseDate(map['createdAt'] ?? map['created_at']);
        if (latest == null ||
            (at != null && (latestAt == null || at.isAfter(latestAt)))) {
          latest = map;
          latestAt = at;
        }
      }
      final picked = latest ?? Map<String, dynamic>.from(messages.last as Map);
      return ChatMessageModel.fromJson(picked);
    }

    return null;
  }

  static ChatMessageModel _syntheticLastMessage({
    required Map<String, dynamic> json,
    required String chatId,
    required String content,
  }) {
    return ChatMessageModel(
      id: (json['lastMessageId'] ?? json['last_message_id'] ?? '').toString(),
      chatId: chatId,
      senderId: (json['lastMessageSenderId'] ??
              json['last_message_sender_id'] ??
              json['lastSenderId'] ??
              '')
          .toString(),
      type: ChatMessageType.text,
      content: content,
      createdAt: _parseDate(
        json['lastMessageAt'] ??
            json['last_message_at'] ??
            json['updatedAt'] ??
            json['updated_at'],
      ),
    );
  }
}
