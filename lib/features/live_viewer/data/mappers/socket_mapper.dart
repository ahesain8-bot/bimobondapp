import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/socket_event.dart';
import '../../../../core/models/live_battle.dart';
import 'hourly_ranking_mapper.dart';

/// Converts Socket.IO payloads (lives/mobile-api.md §16) into typed
/// [SocketEvent]s consumed by the live room UI.
class SocketMapper {
  const SocketMapper._();

  static LiveCommentEvent? commentEvent(dynamic data, String? fallbackLiveId) {
    final map = _asMap(data);
    if (map == null) return null;

    final nested = _asMap(map['comment']) ?? map;
    final user = _asMap(nested['user']) ?? _asMap(map['user']);

    final content =
        nested['content']?.toString() ?? nested['text']?.toString() ?? '';

    final comment = CommentEntity(
      id:
          nested['id']?.toString() ??
          'c_${DateTime.now().microsecondsSinceEpoch}',
      liveId:
          map['liveId']?.toString() ??
          nested['liveId']?.toString() ??
          fallbackLiveId ??
          '',
      userId: user?['id']?.toString() ?? nested['userId']?.toString() ?? '',
      username:
          user?['username']?.toString() ??
          user?['fullName']?.toString() ??
          'User',
      userAvatar: user?['avatarUrl']?.toString(),
      content: content,
      createdAt: _parseDate(nested['createdAt']) ?? DateTime.now(),
      replyToUserId: nested['replyToUserId']?.toString(),
      gifterLevel: _asInt(user?['gifterLevel']),
      isVerified: user?['isVerified'] == true,
      isPinned: nested['isPinned'] == true || nested['pinned'] == true,
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

  static LiveGuestInviteEvent? guestInviteEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;
    final liveId = map['liveId']?.toString() ?? fallbackLiveId ?? '';
    if (liveId.isEmpty) return null;
    final host = _asMap(map['host']) ?? _asMap(map['user']);
    final fullName = host?['fullName']?.toString();
    return LiveGuestInviteEvent(
      liveId: liveId,
      hostName: (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : (host?['username']?.toString() ?? map['hostName']?.toString()),
      role: (map['role'] ?? map['guestRole'])?.toString() ?? 'GUEST',
      timestamp: DateTime.now(),
    );
  }

  static LiveGuestUpdateEvent? guestUpdateEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;
    final type = map['type']?.toString();
    if (type == null || type.isEmpty) return null;
    final guest = _asMap(map['guest']);
    final user = guest == null ? null : _asMap(guest['user']);
    return LiveGuestUpdateEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      updateType: type,
      guestUserId: user?['id']?.toString() ?? guest?['userId']?.toString(),
      timestamp: DateTime.now(),
    );
  }

  static LiveBattleEvent? battleEvent(dynamic data, String? fallbackLiveId) {
    final map = _asMap(data);
    if (map == null) return null;
    final battle = _asMap(map['battle']) ?? _asMap(map['data']) ?? map;
    if (battle['id'] == null) return null;
    final parsed = LiveBattle.fromJson(battle);
    final liveId = map['liveId']?.toString() ?? fallbackLiveId ?? '';
    return LiveBattleEvent(
      liveId: liveId,
      updateType: map['type']?.toString() ?? 'score',
      battle: parsed,
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
      id: map['id']?.toString() ?? 'g_${DateTime.now().microsecondsSinceEpoch}',
      giftId: gift?['id']?.toString() ?? map['giftId']?.toString() ?? '',
      liveId: liveId,
      senderId: sender?['id']?.toString() ?? map['senderId']?.toString() ?? '',
      senderName:
          sender?['username']?.toString() ??
          sender?['fullName']?.toString() ??
          map['senderName']?.toString() ??
          'User',
      senderAvatar: sender?['avatarUrl']?.toString(),
      quantity: _asInt(map['quantity']) ?? _asInt(gift?['quantity']) ?? 1,
      totalCost:
          _asInt(map['totalCost']) ??
          _asInt(map['coins']) ??
          _asInt(gift?['coinCost']) ??
          0,
      sentAt: _parseDate(map['sentAt']) ?? DateTime.now(),
      senderGifterLevel: _asInt(sender?['gifterLevel']),
      giftDetails: gift == null
          ? null
          : GiftEntity(
              id: gift['id']?.toString() ?? '',
              name: gift['name']?.toString() ?? 'Gift',
              iconUrl:
                  gift['iconUrl']?.toString() ??
                  gift['imageUrl']?.toString() ??
                  '',
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

    final rawViewers = _rawViewerValue(map);
    final avatars = avatarUrlsFrom(
      map['topViewers'] ?? map['users'] ?? map['viewersList'] ?? rawViewers,
    );
    final viewers =
        _asInt(rawViewers) ?? (rawViewers is List ? rawViewers.length : null);
    if (viewers == null) return null;

    return LiveViewersEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      viewerCount: viewers,
      topViewerAvatars: avatars,
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

  static LiveCommentDeletedEvent? commentDeletedEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;
    final id = map['commentId']?.toString() ?? map['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return LiveCommentDeletedEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      commentId: id,
      timestamp: DateTime.now(),
    );
  }

  static LiveCommentPinnedEvent? commentPinnedEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final commentEvent = SocketMapper.commentEvent(data, fallbackLiveId);
    if (commentEvent == null) return null;
    return LiveCommentPinnedEvent(
      liveId: commentEvent.liveId,
      comment: commentEvent.comment.copyWith(isPinned: true),
      timestamp: DateTime.now(),
    );
  }

  static LiveCommentUnpinnedEvent? commentUnpinnedEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;
    final id = map['commentId']?.toString() ?? map['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return LiveCommentUnpinnedEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      commentId: id,
      timestamp: DateTime.now(),
    );
  }

  static LiveModerationEvent? moderationEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;
    final type = map['type']?.toString();
    if (type == null || type.isEmpty) return null;
    return LiveModerationEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      moderationType: type,
      userId: map['userId']?.toString(),
      reason: map['reason']?.toString(),
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
    final userId = user['id']?.toString() ?? map['userId']?.toString();
    if (userId == null || userId.isEmpty) return null;

    return UserJoinedEvent(
      liveId: map['liveId']?.toString() ?? fallbackLiveId ?? '',
      userId: userId,
      username:
          user['username']?.toString() ??
          user['fullName']?.toString() ??
          'User',
      avatarUrl: user['avatarUrl']?.toString() ?? user['avatar']?.toString(),
      viewerCount: _viewerCount(map),
      timestamp: DateTime.now(),
    );
  }

  /// `liveHourlyRankUpdated` (mobile-api.md §19). Also accepts the
  /// `livePopularStatus` shape, which sends `reason` / `hourlyRank` instead.
  static LiveHourlyRankEvent? hourlyRankEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;
    final liveId = map['liveId']?.toString() ?? fallbackLiveId ?? '';
    if (liveId.isEmpty) return null;
    return LiveHourlyRankEvent(
      liveId: liveId,
      rank: HourlyRankingMapper.liveRankFromPayload(
        map,
        fallbackLiveId: liveId,
      ),
      timestamp: DateTime.now(),
    );
  }

  static LiveTopGiftersUpdatedEvent? topGiftersEvent(
    dynamic data,
    String? fallbackLiveId,
  ) {
    final map = _asMap(data);
    if (map == null) return null;
    final liveId = map['liveId']?.toString() ?? fallbackLiveId ?? '';
    if (liveId.isEmpty) return null;
    return LiveTopGiftersUpdatedEvent(
      liveId: liveId,
      avatarUrls: avatarUrlsFrom(map['data'] ?? map['gifters']),
      timestamp: DateTime.now(),
    );
  }

  /// Avatar URLs from `topViewers` / `users` / a viewers list, if present.
  static List<String> avatarUrlsFrom(dynamic raw) {
    if (raw is! List) return const [];
    final urls = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        urls.add(item.trim());
        continue;
      }
      final map = _asMap(item);
      if (map == null) continue;
      final user = _asMap(map['user']) ?? map;
      final url = user['avatarUrl']?.toString() ?? user['avatar']?.toString();
      if (url != null && url.trim().isNotEmpty) urls.add(url.trim());
    }
    return urls.take(3).toList();
  }

  static int? _viewerCount(Map<String, dynamic> map) {
    final raw = _rawViewerValue(map);
    return _asInt(raw) ?? (raw is List ? raw.length : null);
  }

  static dynamic _rawViewerValue(Map<String, dynamic> map) {
    return map['viewers'] ??
        map['viewerCount'] ??
        map['viewer_count'] ??
        map['count'];
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
