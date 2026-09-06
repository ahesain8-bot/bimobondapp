/// LIVE House venue (`POST/GET /lives/houses`). Room switching is not documented.
class LiveHouse {
  const LiveHouse({
    required this.id,
    this.title,
    this.status,
    this.roomLiveIds = const [],
  });

  final String id;
  final String? title;

  /// Backend venue status: `OPEN` | `CLOSED` when present.
  final String? status;

  /// Live ids attached as rooms, when the payload includes them.
  final List<String> roomLiveIds;

  bool get isClosed => status?.toUpperCase() == 'CLOSED';

  factory LiveHouse.fromJson(Map<String, dynamic> json) {
    final id =
        json['id']?.toString() ??
        json['houseId']?.toString() ??
        json['house_id']?.toString() ??
        '';
    final rooms = json['rooms'];
    final roomIds = <String>[];
    if (rooms is List) {
      for (final item in rooms) {
        if (item is String && item.isNotEmpty) {
          roomIds.add(item);
          continue;
        }
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final nestedLive = map['live'];
        final nestedId = nestedLive is Map
            ? nestedLive['id']?.toString()
            : null;
        final liveId =
            map['liveId']?.toString() ??
            map['id']?.toString() ??
            nestedId;
        if (liveId != null && liveId.isNotEmpty) roomIds.add(liveId);
      }
    }
    return LiveHouse(
      id: id,
      title: json['title']?.toString(),
      status: json['status']?.toString(),
      roomLiveIds: roomIds,
    );
  }

  /// Tolerant unwrap of create / get / list responses. Returns null when no id.
  static LiveHouse? fromPayload(Map<String, dynamic> payload) {
    final nested = payload['house'] ?? payload['data'];
    if (nested is Map) {
      final house = LiveHouse.fromJson(Map<String, dynamic>.from(nested));
      if (house.id.isNotEmpty) return house;
    }
    final house = LiveHouse.fromJson(payload);
    return house.id.isEmpty ? null : house;
  }

  static List<LiveHouse> listFromPayload(Map<String, dynamic> payload) {
    final data = payload['data'] ?? payload['houses'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => LiveHouse.fromJson(Map<String, dynamic>.from(e)))
          .where((h) => h.id.isNotEmpty)
          .toList(growable: false);
    }
    final single = fromPayload(payload);
    return single == null ? const [] : [single];
  }
}
