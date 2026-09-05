import '../../domain/entities/live_interactive.dart';

class LiveInteractiveMapper {
  const LiveInteractiveMapper._();

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static Map<String, dynamic> unwrap(dynamic payload, String key) {
    final source = map(payload);
    final nested = source[key];
    return nested is Map ? Map<String, dynamic>.from(nested) : source;
  }

  static List<Map<String, dynamic>> list(dynamic payload) {
    final mapPayload = map(payload);
    final raw = mapPayload['data'] ?? mapPayload['items'] ?? payload;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(map).toList(growable: false);
  }

  static int integer(dynamic value, [int fallback = 0]) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;

  static double decimal(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? fallback;

  static bool boolean(dynamic value, [bool fallback = false]) =>
      value is bool ? value : value?.toString().toLowerCase() == 'true' || fallback;

  static DateTime? date(dynamic value) {
    final text = value?.toString();
    return text == null ? null : DateTime.tryParse(text);
  }

  static LiveGiftGoal giftGoal(dynamic payload) {
    final json = unwrap(payload, 'giftGoal');
    return LiveGiftGoal(
      id: json['id']?.toString() ?? '',
      title: json['giftGoalTitle']?.toString() ?? json['title']?.toString(),
      target: integer(json['giftGoalTarget'] ?? json['target']),
      current: integer(json['giftGoalCurrent'] ?? json['current']),
    );
  }

  static LivePoll poll(dynamic payload) {
    final json = unwrap(payload, 'poll');
    final options = json['options'] is List
        ? (json['options'] as List)
              .whereType<Map>()
              .map(
                (raw) {
                  final option = map(raw);
                  return LivePollOption(
                    text: option['text']?.toString() ?? '',
                    votes: integer(option['votes']),
                    percentage: decimal(option['percentage']),
                  );
                },
              )
              .toList(growable: false)
        : const <LivePollOption>[];
    return LivePoll(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      options: options,
      totalVotes: integer(json['totalVotes']),
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: date(json['createdAt']),
    );
  }

  static LiveQA qa(dynamic payload) {
    final json = unwrap(payload, 'qa');
    final user = map(json['user']);
    return LiveQA(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? user['id']?.toString() ?? '',
      username: json['username']?.toString() ??
          user['username']?.toString() ??
          user['fullName']?.toString() ??
          'Viewer',
      question: json['question']?.toString() ?? '',
      isPinned: boolean(json['isPinned']),
      isAnswered: boolean(json['isAnswered']),
      answer: json['answer']?.toString(),
      createdAt: date(json['createdAt']),
    );
  }

  static LiveTreasureBox treasureBox(dynamic payload) {
    final json = unwrap(payload, 'box');
    return LiveTreasureBox(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      totalCoins: integer(json['totalCoins']),
      remainingCoins: integer(
        json['remainingCoins'],
        integer(json['totalCoins']),
      ),
      maxClaims: integer(json['maxClaims']),
      delaySeconds: integer(json['delaySeconds']),
      claimedCount: integer(json['claimedCount']),
      status: json['status']?.toString() ?? 'WAITING',
      createdAt: date(json['createdAt']),
      unlocksAt: date(json['unlocksAt']),
    );
  }

  static LiveTreasureClaim treasureClaim(dynamic payload) {
    final json = unwrap(payload, 'claim');
    return LiveTreasureClaim(
      id: json['id']?.toString() ?? '',
      boxId: json['boxId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      coinsWon: integer(json['coinsWon']),
      claimedCount: integer(json['claimedCount']),
      maxClaims: integer(json['maxClaims']),
      box: treasureBox(json['box'] ?? json),
    );
  }

  static LiveAuction auction(dynamic payload) {
    final json = unwrap(payload, 'auction');
    return LiveAuction(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      itemImageUrl: json['itemImageUrl']?.toString(),
      currentPrice: integer(json['currentPrice']),
      targetPrice: integer(json['targetPrice']),
      status: json['status']?.toString() ?? 'ACTIVE',
      isPinned: boolean(json['isPinned']),
      pinOrder: json['pinOrder'] == null ? null : integer(json['pinOrder']),
      startingPrice: json['startingPrice'] == null
          ? null
          : integer(json['startingPrice']),
      startedAt: date(json['startedAt']),
      endedAt: date(json['endedAt']),
    );
  }

  static LiveHourlyLeaderboardEntry hourlyEntry(dynamic payload) {
    final json = map(payload);
    return LiveHourlyLeaderboardEntry(
      rank: integer(json['rank']),
      score: integer(json['score']),
      hourlyCoins: integer(json['hourlyCoins']),
      isPopular: boolean(json['isPopular']),
      popularReason: json['popularReason']?.toString(),
      live: map(json['live']),
    );
  }

  static LiveGifterLeaderboardEntry gifterEntry(dynamic payload) {
    final json = map(payload);
    return LiveGifterLeaderboardEntry(
      rank: integer(json['rank']),
      totalCoins: integer(json['totalCoins']),
      user: map(json['user']),
    );
  }

  static LiveLeagueTier leagueTier(dynamic payload) {
    final json = map(payload);
    return LiveLeagueTier(
      tier: json['tier']?.toString() ?? '',
      minCoins: integer(json['minCoins']),
      minFollowers: integer(json['minFollowers']),
    );
  }

  static LiveHostLeague hostLeague(dynamic payload) {
    final outer = map(payload);
    final nestedLeague = outer['league'];
    final json = nestedLeague is Map
        ? {...outer, ...map(nestedLeague)}
        : outer;
    return LiveHostLeague(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      hostLeagueTier: json['hostLeagueTier']?.toString() ?? '',
      totalLiveEarnedCoins: integer(json['totalLiveEarnedCoins']),
      followerCount: integer(json['followerCount']),
      nextTier: json['nextTier']?.toString(),
      progressPercentage: decimal(json['progressPercentage']),
    );
  }

  static LiveUserLevelUp userLevelUp(dynamic payload) {
    final json = map(payload);
    return LiveUserLevelUp(
      userId: json['userId']?.toString() ?? '',
      newLevel: integer(json['newLevel']),
      currentXp: integer(json['currentXp']),
      nextLevelXp: integer(json['nextLevelXp']),
      progressPercentage: decimal(json['progressPercentage']),
      liveId: json['liveId']?.toString() ?? '',
    );
  }

  static LiveSummary summary(dynamic payload) {
    final json = unwrap(payload, 'summary');
    final rawGifters = json['topGifters'];
    final gifters = rawGifters is List
        ? rawGifters
              .whereType<Map>()
              .map(
                (raw) {
                  final gifter = map(raw);
                  return LiveSummaryTopGifter(
                    user: map(gifter['user']),
                    totalCoins: integer(gifter['totalCoins']),
                  );
                },
              )
              .toList(growable: false)
        : const <LiveSummaryTopGifter>[];
    return LiveSummary(
      liveId: json['liveId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString(),
      startedAt: date(json['startedAt']),
      endedAt: date(json['endedAt']),
      durationSeconds: integer(json['durationSeconds']),
      peakViewers: integer(json['peakViewers']),
      totalViewerSessions: integer(json['totalViewerSessions']),
      totalLikes: integer(json['totalLikes']),
      totalComments: integer(json['totalComments']),
      totalEarnedCoins: integer(json['totalEarnedCoins']),
      topGifters: gifters,
    );
  }

  static AdminLive adminLive(dynamic payload) {
    final json = map(payload);
    return AdminLive(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      viewers: integer(json['viewers']),
      likeCount: integer(json['likeCount']),
      totalEarnedCoins: integer(json['totalEarnedCoins']),
      roomName: json['roomName']?.toString(),
      streamUrl: json['streamUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      categoryId: json['categoryId']?.toString(),
      banReason: json['banReason']?.toString(),
      feedBoostUntil: date(json['feedBoostUntil']),
      guestsEnabled: json['guestsEnabled'] as bool?,
      guestRequestMode: json['guestRequestMode']?.toString(),
      maxGuests: json['maxGuests'] == null ? null : integer(json['maxGuests']),
      layout: json['layout']?.toString(),
      allowGuestCamera: json['allowGuestCamera'] as bool?,
      moderatorsCanManageGuests: json['moderatorsCanManageGuests'] as bool?,
      user: json['user'] is Map ? map(json['user']) : null,
      category: json['category'] is Map ? map(json['category']) : null,
      activeAuctions: list(json['activeAuctions'])
          .map(auction)
          .toList(growable: false),
      pinnedComment: json['pinnedComment'] is Map
          ? map(json['pinnedComment'])
          : null,
      createdAt: date(json['createdAt']),
      startedAt: date(json['startedAt']),
      endedAt: date(json['endedAt']),
    );
  }
}
