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
      case 'AUDIO':
      case 'VOICE':
        return ChatMessageType.audio;
      case 'LOCATION':
        return ChatMessageType.location;
      case 'FILE':
      case 'DOCUMENT':
        return ChatMessageType.file;
      case 'CONTACT':
        return ChatMessageType.contact;
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

  static List<ChatMessageReactionEntity> _parseReactions(
    Map<String, dynamic> json,
  ) {
    final raw = json['reactions'] ??
        json['Reactions'] ??
        json['messageReactions'] ??
        json['message_reactions'];

    if (raw != null) {
      return _parseReactionsValue(raw);
    }

    final single = json['reaction'] ??
        json['reactionEmoji'] ??
        json['reaction_emoji'] ??
        json['myReaction'] ??
        json['my_reaction'];
    if (single != null && single.toString().trim().isNotEmpty) {
      return [
        ChatMessageReactionEntity(
          userId: _reactionUserId(json),
          emoji: single.toString().trim(),
        ),
      ];
    }

    return const [];
  }

  static String _reactionUserId(Map<String, dynamic> map) {
    return (map['reactionUserId'] ??
            map['reaction_user_id'] ??
            map['userId'] ??
            map['user_id'] ??
            '')
        .toString();
  }

  static List<ChatMessageReactionEntity> _parseReactionsValue(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return [ChatMessageReactionEntity(userId: '', emoji: raw.trim())];
    }

    if (raw is List) {
      final results = <ChatMessageReactionEntity>[];
      for (final item in raw) {
        results.addAll(_parseReactionItem(item));
      }
      return _dedupeReactions(results);
    }

    if (raw is Map) {
      final results = <ChatMessageReactionEntity>[];
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (_looksLikeEmoji(key)) {
          results.add(ChatMessageReactionEntity(userId: '', emoji: key));
          continue;
        }

        if (value is String && value.trim().isNotEmpty) {
          results.add(
            ChatMessageReactionEntity(
              userId: key,
              emoji: value.trim(),
            ),
          );
        } else if (value is List && value.isNotEmpty && _looksLikeEmoji(key)) {
          results.add(ChatMessageReactionEntity(userId: '', emoji: key));
        } else if (value is Map) {
          results.addAll(_parseReactionItem(value));
        }
      }
      return _dedupeReactions(results);
    }

    return const [];
  }

  static List<ChatMessageReactionEntity> _parseReactionItem(dynamic item) {
    if (item is String && item.trim().isNotEmpty) {
      return [ChatMessageReactionEntity(userId: '', emoji: item.trim())];
    }
    if (item is! Map) return const [];

    final map = Map<String, dynamic>.from(item);
    final emoji = (map['emoji'] ??
            map['reaction'] ??
            map['reactionEmoji'] ??
            map['type'] ??
            map['name'] ??
            '')
        .toString()
        .trim();
    if (emoji.isEmpty) return const [];

    final user = map['user'];
    final userId = (map['userId'] ??
            map['user_id'] ??
            (user is Map ? user['id'] ?? user['userId'] : null) ??
            '')
        .toString();

    return [ChatMessageReactionEntity(userId: userId, emoji: emoji)];
  }

  static bool _looksLikeEmoji(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    // Emoji keys from grouped reaction maps (e.g. "❤️": 2).
    return trimmed.length <= 8 && !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  }

  static List<ChatMessageReactionEntity> _dedupeReactions(
    List<ChatMessageReactionEntity> reactions,
  ) {
    final seen = <String>{};
    final unique = <ChatMessageReactionEntity>[];
    for (final reaction in reactions) {
      if (reaction.emoji.isEmpty) continue;
      if (seen.add(reaction.emoji)) {
        unique.add(reaction);
      }
    }
    return unique;
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

  static String? _resolveMediaUrl(
    Map<String, dynamic> json,
    ChatMessageType type,
  ) {
    final media = json['mediaUrl'] ??
        json['media_url'] ??
        json['audioUrl'] ??
        json['audio_url'] ??
        (json['media'] is Map ? (json['media'] as Map)['url'] : null) ??
        (json['attachment'] is Map ? (json['attachment'] as Map)['url'] : null);
    if (media != null) {
      return MediaUtils.resolveAbsoluteUrl(media.toString());
    }

    final content = (json['content'] ?? json['text'])?.toString().trim();
    if (content == null || content.isEmpty) return null;
    final isMediaType = type == ChatMessageType.image ||
        type == ChatMessageType.video ||
        type == ChatMessageType.audio ||
        type == ChatMessageType.file;
    if (isMediaType &&
        (content.startsWith('http://') || content.startsWith('https://'))) {
      return MediaUtils.resolveAbsoluteUrl(content);
    }
    return null;
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['type']?.toString());
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
      type: type,
      content: (json['content'] ?? json['text'] ?? json['message'])?.toString(),
      mediaUrl: _resolveMediaUrl(json, type),
      replyToId: (json['replyToId'] ?? json['reply_to_id'])?.toString(),
      sharedPostId: (json['sharedPostId'] ?? json['shared_post_id'])?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      readByUserIds: _parseReadBy(json['readBy'] ?? json['read_by']),
      reactions: _parseReactions(json),
      isDeleted: json['isDeleted'] == true || json['deleted'] == true,
      replyPreview: replyPreview,
    );
  }
}
