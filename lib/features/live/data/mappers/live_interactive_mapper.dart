import '../../domain/entities/live_interactive.dart';

/// Maps gift goal / poll / Q&A / treasure box / auction / summary JSON from
/// lives/mobile-api.md. Responses arrive either bare or wrapped in a named
/// key, so every mapper unwraps its own envelope before reading fields.
class LiveInteractiveMapper {
  const LiveInteractiveMapper._();

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  /// Returns `payload[key]` when the response wraps the resource, and the
  /// payload itself when the server returns it bare.
  static Map<String, dynamic> _unwrap(dynamic payload, String key) {
    final source = asMap(payload);
    final nested = source[key];
    return nested is Map ? Map<String, dynamic>.from(nested) : source;
  }

  static List<Map<String, dynamic>> listOf(dynamic payload) {
    final source = asMap(payload);
    final raw = source['data'] ?? source['items'] ?? payload;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(asMap).toList(growable: false);
  }

  static LiveGiftGoal giftGoal(dynamic payload) {
    final json = _unwrap(payload, 'giftGoal');
    return LiveGiftGoal(
      id: json['id']?.toString() ?? '',
      title: json['giftGoalTitle']?.toString() ?? json['title']?.toString(),
      target: _asInt(json['giftGoalTarget'] ?? json['target']),
      current: _asInt(json['giftGoalCurrent'] ?? json['current']),
    );
  }

  static LivePoll poll(dynamic payload) {
    final json = _unwrap(payload, 'poll');
    final rawOptions = json['options'];
    return LivePoll(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      options: rawOptions is! List
          ? const <LivePollOption>[]
          : rawOptions.whereType<Map>().map((raw) {
              final option = asMap(raw);
              return LivePollOption(
                text: option['text']?.toString() ?? '',
                votes: _asInt(option['votes']),
                percentage: _asDouble(option['percentage']),
              );
            }).toList(growable: false),
      totalVotes: _asInt(json['totalVotes']),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  static LiveQA qa(dynamic payload) {
    final json = _unwrap(payload, 'qa');
    final user = asMap(json['user']);
    return LiveQA(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      username:
          json['username']?.toString() ??
          user['username']?.toString() ??
          user['fullName']?.toString() ??
          'Viewer',
      question: json['question']?.toString() ?? '',
      isPinned: json['isPinned'] == true,
      isAnswered: json['isAnswered'] == true,
    );
  }

  static LiveTreasureBox treasureBox(dynamic payload) {
    final json = _unwrap(payload, 'box');
    final total = _asInt(json['totalCoins']);
    return LiveTreasureBox(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      totalCoins: total,
      remainingCoins: _asInt(json['remainingCoins'], total),
      maxClaims: _asInt(json['maxClaims']),
      delaySeconds: _asInt(json['delaySeconds']),
      claimedCount: _asInt(json['claimedCount']),
      status: json['status']?.toString() ?? 'WAITING',
      createdAt: _asDate(json['createdAt']),
      unlocksAt: _asDate(json['unlocksAt']),
    );
  }

  static LiveTreasureClaim treasureClaim(dynamic payload) {
    final json = _unwrap(payload, 'claim');
    final box = asMap(json['box']);
    return LiveTreasureClaim(
      boxId: json['boxId']?.toString() ?? box['id']?.toString() ?? '',
      coinsWon: _asInt(json['coinsWon']),
      claimedCount: _asInt(json['claimedCount'] ?? box['claimedCount']),
      remainingCoins: _asInt(json['remainingCoins'] ?? box['remainingCoins']),
    );
  }

  static LiveAuction auction(dynamic payload) {
    final json = _unwrap(payload, 'auction');
    return LiveAuction(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      currentPrice: _asInt(json['currentPrice']),
      targetPrice: _asInt(json['targetPrice']),
      status: json['status']?.toString() ?? 'ACTIVE',
      isPinned: json['isPinned'] == true,
      startingPrice: json['startingPrice'] == null
          ? null
          : _asInt(json['startingPrice']),
    );
  }

  static LiveSummary summary(dynamic payload) {
    final json = _unwrap(payload, 'summary');
    final rawGifters = json['topGifters'];
    return LiveSummary(
      liveId: json['liveId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      durationSeconds: _asInt(json['durationSeconds']),
      peakViewers: _asInt(json['peakViewers']),
      totalViewerSessions: _asInt(json['totalViewerSessions']),
      totalLikes: _asInt(json['totalLikes']),
      totalComments: _asInt(json['totalComments']),
      totalEarnedCoins: _asInt(json['totalEarnedCoins']),
      topGifters: rawGifters is! List
          ? const <LiveSummaryTopGifter>[]
          : rawGifters.whereType<Map>().map((raw) {
              final gifter = asMap(raw);
              final user = asMap(gifter['user']);
              return LiveSummaryTopGifter(
                displayName:
                    user['fullName']?.toString() ??
                    user['username']?.toString() ??
                    'Viewer',
                totalCoins: _asInt(gifter['totalCoins']),
              );
            }).toList(growable: false),
    );
  }

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic value) {
    final text = value?.toString();
    return text == null ? null : DateTime.tryParse(text);
  }
}
