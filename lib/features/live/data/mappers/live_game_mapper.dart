import '../../domain/entities/live_game.dart';

/// Parses the official-games payloads (`lives/live-p3-parity.md` §3).
///
/// The response envelopes are not spelled out in the supplied documents, so the
/// parser accepts the documented field names, tolerates a `data`/`game`
/// wrapper, and leaves anything it does not recognise as unknown rather than
/// inventing a value. A missing quiz `correctIndex` means "not revealed yet".
class LiveGameMapper {
  const LiveGameMapper._();

  static Map<String, dynamic>? _unwrap(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    for (final key in ['game', 'data', 'activeGame']) {
      final nested = map[key];
      if (nested is Map) {
        final inner = Map<String, dynamic>.from(nested);
        // Keep viewer-scoped fields that sit next to the wrapper.
        for (final passthrough in ['myPlay', 'me', 'played', 'hasPlayed']) {
          if (map.containsKey(passthrough) && !inner.containsKey(passthrough)) {
            inner[passthrough] = map[passthrough];
          }
        }
        return inner;
      }
    }
    return map;
  }

  static List<LiveGameCatalogEntry> catalogFromJson(Map<String, dynamic> json) {
    final raw =
        json['data'] ?? json['games'] ?? json['catalog'] ?? json['items'];
    if (raw is! List) return const [];
    final entries = <LiveGameCatalogEntry>[];
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final type = LiveGameType.parse(
        _string(map['type'] ?? map['gameType'] ?? map['slug']),
      );
      if (type == LiveGameType.unknown) continue;
      entries.add(
        LiveGameCatalogEntry(
          type: type,
          name: _string(map['name'] ?? map['title']) ?? '',
          description: _string(map['description']),
          iconUrl: _string(map['iconUrl'] ?? map['imageUrl']),
        ),
      );
    }
    return List.unmodifiable(entries);
  }

  /// Returns null when the payload carries no game — an empty body is the
  /// documented "no ACTIVE game", not an error.
  static LiveGame? gameFromJson(Map<String, dynamic>? json) {
    final map = _unwrap(json);
    if (map == null) return null;
    final id = _string(map['id'] ?? map['gameId']);
    final type = LiveGameType.parse(_string(map['type'] ?? map['gameType']));
    if (id == null || id.isEmpty) return null;

    final plays = _playsFromJson(map['plays'] ?? map['entries']);
    final myPlay = _unwrapMyPlay(map);
    return LiveGame(
      id: id,
      type: type,
      status: LiveGameStatus.parse(_string(map['status'])),
      question: _string(map['question']),
      options: _stringList(map['options']),
      // Absent until the host ends a quiz. Never defaulted to an index.
      correctIndex: _intOrNull(map['correctIndex']),
      prizes: _stringList(map['prizes']),
      plays: plays,
      myPlayed:
          map['hasPlayed'] == true ||
          map['played'] == true ||
          map['myPlayed'] == true ||
          myPlay != null,
      myOptionIndex: myPlay == null
          ? _intOrNull(map['myOptionIndex'])
          : _intOrNull(myPlay['optionIndex']),
      winnerUserId: _string(
        map['winnerUserId'] ??
            (map['winner'] is Map
                ? (map['winner'] as Map)['userId'] ??
                      (map['winner'] as Map)['id']
                : null),
      ),
      winnerName: _string(
        map['winnerName'] ??
            (map['winner'] is Map
                ? (map['winner'] as Map)['username'] ??
                      (map['winner'] as Map)['fullName']
                : null),
      ),
      resultPrize: _string(map['prize'] ?? map['result'] ?? map['resultPrize']),
      playCount: _intOrNull(map['playCount'] ?? map['playsCount']),
    );
  }

  static Map<String, dynamic>? _unwrapMyPlay(Map<String, dynamic> map) {
    for (final key in ['myPlay', 'me']) {
      final value = map[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<LiveGamePlay> _playsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final plays = <LiveGamePlay>[];
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final user = map['user'] is Map
          ? Map<String, dynamic>.from(map['user'] as Map)
          : const <String, dynamic>{};
      final userId = _string(map['userId'] ?? user['id']);
      if (userId == null || userId.isEmpty) continue;
      plays.add(
        LiveGamePlay(
          userId: userId,
          username: _string(user['username'] ?? user['fullName']),
          avatarUrl: _string(user['avatarUrl']),
          optionIndex: _intOrNull(map['optionIndex']),
          score: map['score'] is num ? map['score'] as num : null,
          prize: _string(map['prize']),
          isWinner: map['isWinner'] == true || map['winner'] == true,
        ),
      );
    }
    return List.unmodifiable(plays);
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return List.unmodifiable(
      value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
    );
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
