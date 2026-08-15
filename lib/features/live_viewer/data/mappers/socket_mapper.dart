import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/socket_event.dart';

/// Converts Socket.IO payloads (lives/mobile-api.md §16) into typed
/// [SocketEvent]s consumed by the live room UI.
class SocketMapper {
  const SocketMapper._();

  static LiveCommentEvent? commentEvent(dynamic data, String? fallbackLiveId) {
    final map = _asMap(data);
    if (map == null) return null;

    final nested = _asMap(map['comment']) ?? map;
    final user = _asMap(nested['user']) ?? _asMap(map['user']);

    final content = nested['content']?.toString() ??
        nested['text']?.toString() ??
        '';

    final comment = CommentEntity(
      id: nested['id']?.toString() ??
          'c_${DateTime.now().microsecondsSinceEpoch}',
      liveId: map['liveId']?.toString() ??
          nested['liveId']?.toString() ??
          fallbackLiveId ??
          '',
      userId: user?['id']?.toString() ??
          nested['userId']?.toString() ??
          '',
      username: user?['username']?.toString() ??
          user?['fullName']?.toString() ??
          'User',
      userAvatar: user?['avatarUrl']?.toString(),
      content: content,
      createdAt:
          _parseDate(nested['createdAt']) ?? DateTime.now(),
      replyToUserId: nested['replyToUserId']?.toString(),
      metadata: nested['isPinned'] == true || nested['pinned'] == true
          ? const {'pinned': true}
          : null,
    );

    return LiveCommentEvent(
      liveId: comment.liveId,
      comment: comment,
      timestamp: DateTime.now(),
    );
  }

  static LiveGiftEvent? giftEvent(dynamic data, String? fallbackLiveId) {
    final map = _asMap(data);
    if (map == null) return null;

    final liveId = map['liveId']?.toString() ?? fallbackLiveId ?? '';
    final sender = _asMap(map['sender']) ?? _asMap(map['user']);
    final gift = _asMap(map['gift']);

    final giftSent = GiftSentEntity(
      id: map['id']?.toString() ??
          'g_${DateTime.now().microsecondsSinceEpoch}',
      giftId: gift?['id']?.toString() ?? map['giftId']?.toString() ?? '',
      liveId: liveId,
      senderId: sender?['id']?.toString() ??
          map['senderId']?.toString() ??
          '',
      senderName: sender?['username']?.toString() ??
          sender?['fullName']?.toString() ??
          map['senderName']?.toString() ??
          'User',
      senderAvatar: sender?['avatarUrl']?.toString(),
      quantity: _asInt(map['quantity']) ?? _asInt(gift?['quantity']) ?? 1,
      totalCost: _asInt(map['totalCost']) ??
          _asInt(map['coins']) ??
          _asInt(gift?['coinCost']) ??
          0,
      sentAt: _parseDate(map['sentAt']) ?? DateTime.now(),
      giftDetails: gift == null
          ? null
          : GiftEntity(
              id: gift['id']?.toString() ?? '',
              name: gift['name']?.toString() ?? 'Gift',
              iconUrl: gift['iconUrl']?.toString() ?? gift['imageUrl']?.toString() ?? '',
              coinCost: _asInt(gift['coinCost']) ?? 0,
            ),
    );

    return LiveGiftEvent(
      liveId: liveId,
      gift: giftSent,
      timestamp: DateTime.now(),
    );
  }

  static LiveLikeEvent? likeEvent(dynamic data, String? fallbackLiveId) {
    final map = _asMap(data);
    if (map == null) return null;

    final likeCount = _asInt(map['likeCount']);
    if (likeCount == null) return null;

    return LiveLikeEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      likeCount: likeCount,
      delta: _asInt(map['delta']) ?? 1,
      userId: map['userId']?.toString(),
      timestamp: DateTime.now(),
    );
  }

  static LiveViewersEvent? viewersEvent(dynamic data, String? fallbackLiveId) {
    final map = _asMap(data);
    if (map == null) return null;

    final viewers = _asInt(map['viewers'] ?? map['count']);
    if (viewers == null) return null;

    return LiveViewersEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      viewerCount: viewers,
      timestamp: DateTime.now(),
    );
  }

  static LiveEndedEvent? endedEvent(dynamic data, String? fallbackLiveId) {
    final map = _asMap(data);
    if (map == null) return null;

    return LiveEndedEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      reason: map['reason']?.toString() ?? 'Host ended the live',
      timestamp: DateTime.now(),
    );
  }

  static UserJoinedEvent? userJoinedEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;

    final user = _asMap(map['user']) ?? map;
    final userId = user['id']?.toString() ??
        map['userId']?.toString();
    if (userId == null || userId.isEmpty) return null;

    return UserJoinedEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      userId: userId,
      username: user['username']?.toString() ??
          user['fullName']?.toString() ??
          'User',
      avatarUrl: user['avatarUrl']?.toString(),
      timestamp: DateTime.now(),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
