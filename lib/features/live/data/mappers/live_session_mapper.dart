import '../../domain/entities/live_chat_message.dart';
import '../../domain/entities/live_host.dart';
import '../../domain/entities/live_session.dart';
import '../../../../core/models/live_media_hints.dart';

/// Maps Nest live / comment JSON (lives/mobile-api.md) into domain entities.
class LiveSessionMapper {
  const LiveSessionMapper._();

  static LiveHost hostFromUser(Map<String, dynamic>? user, {String? userId}) {
    if (user == null) {
      return LiveHost(id: userId ?? '', displayName: 'Host');
    }
    final fullName = user['fullName']?.toString();
    final username = user['username']?.toString();
    final display = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : (username ?? 'Host');
    return LiveHost(
      id: user['id']?.toString() ?? userId ?? '',
      displayName: display,
      avatarUrl: user['avatarUrl']?.toString(),
      username: username,
      isVerified: user['isVerified'] == true,
      hostHeartCount: _asInt(user['hostHeartCount']) ?? 0,
      hostLeagueTier: user['hostLeagueTier']?.toString(),
    );
  }

  static LiveSession fromLiveJson(
    Map<String, dynamic> live, {
    String? liveKitToken,
    String? liveKitUrl,
    String? liveKitRole,
    LiveMediaHints? mediaHints,
    List<LiveChatMessage> messages = const [],
    int? galleryCurrent,
    int? galleryTotal,
    int? guestInviteCount,
    String? hourlyRankingLabel,
  }) {
    final hourlyRank = _asInt(live['hourlyRank']);
    final label =
        hourlyRankingLabel ??
        (hourlyRank != null ? 'ترتيب #$hourlyRank' : 'ترتيب كل ساعة');

    return LiveSession(
      id: live['id']?.toString() ?? '',
      host: hostFromUser(
        live['user'] as Map<String, dynamic>?,
        userId: live['userId']?.toString(),
      ),
      viewerCount:
          _asInt(
            live['viewers'] ??
                live['viewerCount'] ??
                live['viewer_count'] ??
                live['count'],
          ) ??
          0,
      likeCount: _asInt(live['likeCount']) ?? 0,
      galleryCurrent: galleryCurrent ?? 0,
      galleryTotal: galleryTotal ?? 0,
      guestInviteCount: guestInviteCount ?? 0,
      hourlyRankingLabel: label,
      messages: messages,
      title: live['title']?.toString(),
      status: live['status']?.toString() ?? 'LIVE',
      roomName: live['roomName']?.toString(),
      streamUrl: live['streamUrl']?.toString(),
      coverUrl: live['coverUrl']?.toString(),
      categoryId: live['categoryId']?.toString(),
      guestsEnabled: live['guestsEnabled'] as bool?,
      guestRequestMode: live['guestRequestMode']?.toString(),
      maxGuests: _asInt(live['maxGuests']),
      layout: live['layout']?.toString(),
      allowGuestCamera: live['allowGuestCamera'] as bool?,
      moderatorsCanManageGuests: live['moderatorsCanManageGuests'] as bool?,
      liveKitToken: liveKitToken,
      liveKitUrl: liveKitUrl,
      liveKitRole: liveKitRole,
      mediaHints: mediaHints,
      hourlyRank: hourlyRank,
      totalEarnedCoins: _asInt(live['totalEarnedCoins']) ?? 0,
      isPopular: live['isPopular'] as bool?,
      popularReason: live['popularReason']?.toString(),
    );
  }

  static LiveChatMessage commentFromJson(Map<String, dynamic> json) {
    // Pin events wrap the comment: `{ liveId, comment: {…} }`.
    final nested = json['comment'];
    final source = nested is Map<String, dynamic>
        ? nested
        : (nested is Map ? _asStringMap(nested)! : json);

    final user = _asStringMap(source['user']);
    final gifterLevel = _asInt(user?['gifterLevel']);
    final content =
        source['content']?.toString() ?? source['text']?.toString() ?? '';
    // Same order the host branch above uses: the real name first, the
    // generated handle only as a fallback. Reversed, every comment showed
    // `user_e309173c` instead of the person's name.
    final fullName = user?['fullName']?.toString();
    final handle = user?['username']?.toString();
    final username = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : handle;
    final displayText = username == null || username.isEmpty
        ? content
        : '$username: $content';

    return LiveChatMessage(
      id:
          source['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      text: displayText,
      body: content,
      avatarUrl: user?['avatarUrl']?.toString() ?? user?['avatar']?.toString(),
      showBadge: (gifterLevel ?? 0) > 0,
      userId: user?['id']?.toString() ?? source['userId']?.toString(),
      username: username,
      gifterLevel: gifterLevel,
      isPinned: source['isPinned'] == true || source['pinned'] == true,
    );
  }

  /// Tolerant map read. A hard `as Map<String, dynamic>?` threw on any payload
  /// whose nested objects arrived as `Map<dynamic, dynamic>` — and because the
  /// throw happened inside a Socket.IO handler it was swallowed, so the host
  /// silently lost every viewer comment while their own still appeared.
  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, v) => MapEntry(key.toString(), v));
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
