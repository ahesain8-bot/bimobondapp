import 'dart:math';

import '../../core/constants/api_constants.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../services/fake_livekit_service.dart';

/// Remote API contract. Today this is an in-memory mock that mimics
/// REST latency and payloads. Replace with Dio/Retrofit later.
abstract class LiveRemoteDataSource {
  Future<List<LiveEntity>> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
  });

  Future<LiveEntity> getLiveById(String liveId);

  Future<JoinLiveResult> joinLive(String liveId);

  Future<void> leaveLive(String liveId);

  Future<List<String>> getTrendingCategories();

  Future<void> followHost(String hostId);

  Future<void> unfollowHost(String hostId);
}

class FakeLiveRemoteDataSource implements LiveRemoteDataSource {
  final Random _random = Random();
  final Map<String, LiveEntity> _cache = {};

  static const _categories = [
    'Music',
    'Gaming',
    'Talk Show',
    'DIY',
    'Food',
    'Fashion',
    'Sports',
    'Education',
    'Comedy',
    'Dance',
  ];

  static const _hosts = [
    {'name': 'Alice Chen', 'avatar': 'https://i.pravatar.cc/150?u=alice'},
    {'name': 'Bob Smith', 'avatar': 'https://i.pravatar.cc/150?u=bob'},
    {'name': 'Carol Wu', 'avatar': 'https://i.pravatar.cc/150?u=carol'},
    {'name': 'David Lee', 'avatar': 'https://i.pravatar.cc/150?u=david'},
    {'name': 'Emma Brown', 'avatar': 'https://i.pravatar.cc/150?u=emma'},
    {'name': 'Frank Yang', 'avatar': 'https://i.pravatar.cc/150?u=frank'},
    {'name': 'Grace Liu', 'avatar': 'https://i.pravatar.cc/150?u=grace'},
    {'name': 'Henry Zhang', 'avatar': 'https://i.pravatar.cc/150?u=henry'},
    {'name': 'Ivy Wang', 'avatar': 'https://i.pravatar.cc/150?u=ivy'},
    {'name': 'Jake Miller', 'avatar': 'https://i.pravatar.cc/150?u=jake'},
  ];

  static const _titles = [
    'Friday Night Live! 🎉',
    'Let\'s Chat and Chill ☕',
    'Gaming Session - Join Me! 🎮',
    'Cooking Show: Italian Cuisine 🍝',
    'Study With Me 📚',
    'Workout Session 💪',
    'ASMR Relaxation 😴',
    'Q&A Session - Ask Me Anything ❓',
    'Talent Show Auditions 🎭',
    'Behind the Scenes 🎬',
    'Late Night Vibes 🌙',
    'Dance Battle Ready? 💃',
  ];

  @override
  Future<List<LiveEntity>> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    // Simulate end of pagination after page 5.
    if (page > 5) return [];

    final lives = List.generate(
      limit,
      (i) => _generateLive(
        id: 'live_p${page}_$i',
        category: category,
      ),
    );

    for (final live in lives) {
      _cache[live.id] = live;
    }
    return lives;
  }

  @override
  Future<LiveEntity> getLiveById(String liveId) async {
    await Future.delayed(const Duration(milliseconds: 450));
    if (_cache.containsKey(liveId)) return _cache[liveId]!;
    final live = _generateLive(id: liveId);
    _cache[liveId] = live;
    return live;
  }

  @override
  Future<JoinLiveResult> joinLive(String liveId) async {
    // POST /lives/:id/join
    await Future.delayed(const Duration(milliseconds: 550));
    final live = await getLiveById(liveId);

    if (live.status == LiveStatus.banned) {
      throw Exception('BANNED');
    }
    if (live.status == LiveStatus.ended) {
      throw Exception('ENDED');
    }

    return JoinLiveResult(
      liveId: liveId,
      socketToken: 'sock_${liveId}_${DateTime.now().millisecondsSinceEpoch}',
      liveKitToken: 'lk_${liveId}_${DateTime.now().millisecondsSinceEpoch}',
      liveKitUrl: 'wss://livekit.tiktoklive.mock',
      live: live.copyWith(
        streamUrl: FakeLiveKitService.defaultMockStreamUrl,
      ),
    );
  }

  @override
  Future<void> leaveLive(String liveId) async {
    // POST /lives/:id/leave
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<List<String>> getTrendingCategories() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_categories);
  }

  @override
  Future<void> followHost(String hostId) async {
    await Future.delayed(const Duration(milliseconds: 280));
  }

  @override
  Future<void> unfollowHost(String hostId) async {
    await Future.delayed(const Duration(milliseconds: 280));
  }

  /// Endpoint path helpers for documentation / future Dio mapping.
  String feedPath() => ApiConstants.livesFeed;
  String joinPath(String id) =>
      ApiConstants.joinLive.replaceAll('{id}', id);
  String leavePath(String id) =>
      ApiConstants.leaveLive.replaceAll('{id}', id);

  LiveEntity _generateLive({String? id, String? category}) {
    final host = _hosts[_random.nextInt(_hosts.length)];
    final cat = category ?? _categories[_random.nextInt(_categories.length)];
    final title = _titles[_random.nextInt(_titles.length)];
    final liveId = id ?? 'live_${_random.nextInt(1000000)}';
    final seed = liveId.hashCode.abs() % 1000;

    // Occasionally produce ended/banned for state demos (~4%).
    var status = LiveStatus.live;
    final roll = _random.nextDouble();
    if (roll < 0.02) {
      status = LiveStatus.ended;
    } else if (roll < 0.04) {
      status = LiveStatus.banned;
    }

    return LiveEntity(
      id: liveId,
      hostId: 'host_${host['name']!.hashCode.abs()}',
      hostName: host['name']!,
      hostAvatar: host['avatar'],
      title: title,
      description: 'Join me for an amazing $cat live session!',
      thumbnailUrl: 'https://picsum.photos/seed/$seed/400/700',
      streamUrl: FakeLiveKitService.defaultMockStreamUrl,
      category: cat,
      viewerCount: 100 + _random.nextInt(50000),
      likeCount: _random.nextInt(1000000),
      startTime:
          DateTime.now().subtract(Duration(minutes: _random.nextInt(120))),
      status: status,
      isLive: status == LiveStatus.live,
      metadata: _buildMetadata(liveId, host['name']!),
    );
  }

  Map<String, dynamic> _buildMetadata(String liveId, String hostName) {
    final random = Random(liveId.hashCode);
    final roll = random.nextDouble();
    final isPk = roll < 0.28;
    final isMultiGrid = !isPk && roll < 0.48;
    final isMultiGuest = !isPk && !isMultiGrid && roll < 0.68;
    final guest = _hosts[random.nextInt(_hosts.length)];
    final guests = List.generate(
      isMultiGrid ? 7 : (isMultiGuest ? 1 : 0),
      (i) {
        final g = _hosts[(random.nextInt(_hosts.length) + i) % _hosts.length];
        return {
          'id': 'guest_${liveId}_$i',
          'name': g['name'],
          'avatar': g['avatar'],
          'level': 8 + random.nextInt(70),
          'muted': random.nextBool(),
        };
      },
    );

    return {
      'isPk': isPk,
      'isMultiGrid': isMultiGrid,
      'isMultiGuest': isMultiGuest,
      'location': ['Yalla KSA', 'Riyadh', 'Dubai', 'Cairo', 'Live'][
          random.nextInt(5)],
      'hourlyRank': 1 + random.nextInt(50),
      'goalProgress': '${random.nextInt(8)}/${1 + random.nextInt(3)}',
      'shareCount': 20 + random.nextInt(200),
      'showFanClub': random.nextDouble() < 0.7,
      'showGiftGoal': isMultiGrid ? true : random.nextDouble() < 0.55,
      'giftGoalCurrent': random.nextInt(18),
      'giftGoalTarget': 5 + random.nextInt(20),
      'guests': guests,
      if (isPk) ...{
        'guestName': guest['name'],
        'guestAvatar': guest['avatar'],
        'scoreLeft': 5000 + random.nextInt(15000),
        'scoreRight': 800 + random.nextInt(5000),
        'pkContributorsLeft': List.generate(
          3,
          (i) => 'https://i.pravatar.cc/150?u=${liveId}_L$i',
        ),
        'pkContributorsRight': List.generate(
          3,
          (i) => 'https://i.pravatar.cc/150?u=${liveId}_R$i',
        ),
      },
    };
  }
}
