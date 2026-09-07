import '../../domain/entities/live_cohost.dart';

/// Parses the co-host payloads (`lives/live-p1-parity.md` §6,
/// `live-p2-parity.md` §2).
///
/// `cohost` is the first partner for older clients and `cohosts[]` is the full
/// list; both are folded into one de-duplicated list keyed by live id, so a
/// payload that carries both does not tile the same room twice.
class LiveCohostMapper {
  const LiveCohostMapper._();

  /// The documented ceiling: a room plus three partners.
  static const int maxPartnerRooms = 3;

  static LiveCohostPayload payloadFromJson(
    Map<String, dynamic>? json, {
    String? selfLiveId,
  }) {
    if (json == null) return LiveCohostPayload.none;
    final rooms = <String, LiveCohostRoom>{};

    void add(dynamic value) {
      final room = _roomFromJson(value);
      if (room == null || !room.isConnectable) return;
      // Never tile our own room as a partner.
      if (selfLiveId != null && room.liveId == selfLiveId) return;
      rooms.putIfAbsent(room.liveId, () => room);
    }

    add(json['cohost']);
    final list = json['cohosts'];
    if (list is List) {
      for (final entry in list) {
        add(entry);
      }
    }
    return LiveCohostPayload(
      rooms: List.unmodifiable(
        rooms.values.take(maxPartnerRooms).toList(growable: false),
      ),
    );
  }

  static LiveCohostRoom? _roomFromJson(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final host = map['host'] is Map
        ? Map<String, dynamic>.from(map['host'] as Map)
        : const <String, dynamic>{};
    final liveId = _string(map['liveId'] ?? map['id']);
    final token = _string(map['token']);
    final url = _string(map['url']);
    if (liveId == null || token == null || url == null) return null;
    return LiveCohostRoom(
      liveId: liveId,
      token: token,
      url: url,
      roomName: _string(map['roomName']),
      role: _string(map['role']),
      hostId: _string(host['id'] ?? map['hostId']),
      hostName: _string(host['username'] ?? host['fullName']),
      hostAvatarUrl: _string(host['avatarUrl']),
    );
  }

  static List<LiveCohostSession> sessionsFromJson(Map<String, dynamic> json) {
    final raw =
        json['data'] ?? json['sessions'] ?? json['cohosts'] ?? json['items'];
    if (raw is! List) {
      final single = _sessionFromJson(json);
      return single == null ? const [] : List.unmodifiable([single]);
    }
    final sessions = <LiveCohostSession>[];
    for (final entry in raw.whereType<Map>()) {
      final session = _sessionFromJson(Map<String, dynamic>.from(entry));
      if (session != null) sessions.add(session);
    }
    return List.unmodifiable(sessions);
  }

  /// A single session envelope, e.g. the invite/accept response.
  static LiveCohostSession? sessionFromJson(Map<String, dynamic> json) {
    final nested = json['session'] ?? json['cohost'] ?? json['data'];
    if (nested is Map) {
      return _sessionFromJson(Map<String, dynamic>.from(nested));
    }
    return _sessionFromJson(json);
  }

  static LiveCohostSession? _sessionFromJson(Map<String, dynamic> map) {
    final id = _string(map['id'] ?? map['sessionId']);
    if (id == null) return null;
    final guest = map['guest'] is Map
        ? Map<String, dynamic>.from(map['guest'] as Map)
        : (map['guestUser'] is Map
              ? Map<String, dynamic>.from(map['guestUser'] as Map)
              : const <String, dynamic>{});
    return LiveCohostSession(
      id: id,
      status: LiveCohostStatus.parse(_string(map['status'])),
      hostLiveId: _string(map['hostLiveId'] ?? map['liveId']),
      guestLiveId: _string(map['guestLiveId']),
      hostUserId: _string(map['hostUserId']),
      guestUserId: _string(map['guestUserId'] ?? guest['id']),
      guestName: _string(guest['username'] ?? guest['fullName']),
      guestAvatarUrl: _string(guest['avatarUrl']),
    );
  }

  /// `GET /lives/:id/cohost/hosts` — candidate partner rooms.
  static List<LiveCohostCandidate> candidatesFromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['data'] ?? json['hosts'] ?? json['items'];
    if (raw is! List) return const [];
    final candidates = <LiveCohostCandidate>[];
    for (final entry in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final live = map['live'] is Map
          ? Map<String, dynamic>.from(map['live'] as Map)
          : map;
      final user = map['user'] is Map
          ? Map<String, dynamic>.from(map['user'] as Map)
          : (live['user'] is Map
                ? Map<String, dynamic>.from(live['user'] as Map)
                : const <String, dynamic>{});
      final liveId = _string(live['id'] ?? live['liveId'] ?? map['liveId']);
      if (liveId == null) continue;
      candidates.add(
        LiveCohostCandidate(
          liveId: liveId,
          title: _string(live['title']) ?? '',
          hostId: _string(user['id'] ?? live['userId']) ?? '',
          hostName:
              _string(user['fullName'] ?? user['username']) ?? '',
          hostAvatarUrl: _string(user['avatarUrl']),
          viewers: _int(live['viewers'] ?? live['viewerCount']),
        ),
      );
    }
    return List.unmodifiable(candidates);
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// A live the host may invite to co-host.
class LiveCohostCandidate {
  const LiveCohostCandidate({
    required this.liveId,
    this.title = '',
    this.hostId = '',
    this.hostName = '',
    this.hostAvatarUrl,
    this.viewers,
  });

  final String liveId;
  final String title;
  final String hostId;
  final String hostName;
  final String? hostAvatarUrl;
  final int? viewers;
}
