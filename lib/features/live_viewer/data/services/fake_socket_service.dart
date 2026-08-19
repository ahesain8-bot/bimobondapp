import 'dart:async';
import 'dart:math';

import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/socket_event.dart';

/// Contract for realtime socket. Swap [FakeSocketService] with a real
/// WebSocket implementation later without touching presentation code.
abstract class SocketService {
  Stream<SocketEvent> get events;
  bool get isConnected;
  String? get currentLiveId;

  Future<void> connect({required String liveId, required String token});

  Future<void> disconnect();

  Future<void> emitComment(CommentEntity comment);
  Future<void> emitLike({required int likeCount, int delta = 1});
  Future<void> emitGift(GiftSentEntity gift);

  /// Force a simulated network drop (for testing reconnect UI).
  void simulateNetworkLoss();
}

/// Periodically emits TikTok-like live events so the room feels alive.
class FakeSocketService implements SocketService {
  final _controller = StreamController<SocketEvent>.broadcast();
  final _random = Random();

  Timer? _commentTimer;
  Timer? _likeTimer;
  Timer? _viewerTimer;
  Timer? _giftTimer;
  Timer? _joinTimer;
  Timer? _endTimer;
  Timer? _networkChaosTimer;
  Timer? _reconnectTimer;

  String? _liveId;
  bool _connected = false;
  int _viewerCount = 0;
  int _likeCount = 0;
  int _reconnectAttempt = 0;

  static const _usernames = [
    'Alex',
    'Blake',
    'Casey',
    'Drew',
    'Emery',
    'Finley',
    'Gray',
    'Harper',
    'Indigo',
    'Jordan',
    'Kai',
    'Logan',
    'Morgan',
    'Nova',
    'Oakley',
    'Parker',
    'Quinn',
    'Riley',
    'Sage',
    'Taylor',
    'Uma',
    'Val',
    'Winter',
    'Xen',
    'Yuki',
    'Zara',
    'StarGazer',
    'NightOwl',
    'Dreamer',
    'Luna',
  ];

  static const _comments = [
    'Hello! 👋',
    'Amazing stream! 🔥',
    'Love this! ❤️',
    'So cool! ✨',
    'Hi from USA! 🇺🇸',
    'Big fan! 🎉',
    'First time here 🙌',
    'You\'re hilarious 😂',
    'What song is this? 🎵',
    'Can\'t stop watching 👀',
    'Greetings from Japan 🇯🇵',
    'Let\'s goo! 💪',
    'This vibe tho 😌',
    'Send gifts guys 🎁',
    'Followed! ✨',
    'Respect 👏',
    'How long have you been live?',
    'Best LIVE today 🏆',
  ];

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  String? get currentLiveId => _liveId;

  void seedCounts({required int viewers, required int likes}) {
    _viewerCount = viewers;
    _likeCount = likes;
  }

  @override
  Future<void> connect({required String liveId, required String token}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _liveId = liveId;
    _connected = true;
    _reconnectAttempt = 0;
    _startEmitters();

    // Rarely end the live after a long session (~3% chance after 90–180s).
    _endTimer?.cancel();
    _endTimer = Timer(Duration(seconds: 90 + _random.nextInt(90)), () {
      if (!_connected || _liveId == null) return;
      if (_random.nextDouble() > 0.03) return;
      _controller.add(
        LiveEndedEvent(liveId: _liveId!, timestamp: DateTime.now()),
      );
      disconnect();
    });

    // Occasional network blip for reconnect UX (disabled by default density).
    _networkChaosTimer?.cancel();
    if (_random.nextDouble() < 0.15) {
      _networkChaosTimer = Timer(
        Duration(seconds: 45 + _random.nextInt(60)),
        simulateNetworkLoss,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _stopEmitters();
    _connected = false;
    _liveId = null;
    await Future.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<void> emitComment(CommentEntity comment) async {
    if (!_connected || _liveId == null) return;
    _controller.add(
      LiveCommentEvent(
        liveId: _liveId!,
        comment: comment,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> emitLike({required int likeCount, int delta = 1}) async {
    if (!_connected || _liveId == null) return;
    _likeCount = likeCount;
    _controller.add(
      LiveLikeEvent(
        liveId: _liveId!,
        likeCount: likeCount,
        delta: delta,
        userId: 'current_user',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> emitGift(GiftSentEntity gift) async {
    if (!_connected || _liveId == null) return;
    _controller.add(
      LiveGiftEvent(liveId: _liveId!, gift: gift, timestamp: DateTime.now()),
    );
  }

  @override
  void simulateNetworkLoss() {
    if (!_connected || _liveId == null) return;
    final liveId = _liveId!;
    _stopEmitters();
    _connected = false;
    _controller.add(
      NetworkLostEvent(liveId: liveId, timestamp: DateTime.now()),
    );
    _attemptReconnect(liveId);
  }

  void _attemptReconnect(String liveId) {
    _reconnectAttempt++;
    _controller.add(
      ReconnectingEvent(
        liveId: liveId,
        attempt: _reconnectAttempt,
        timestamp: DateTime.now(),
      ),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      if (_liveId != null && _liveId != liveId) return;
      _liveId = liveId;
      _connected = true;
      _controller.add(
        ReconnectedEvent(liveId: liveId, timestamp: DateTime.now()),
      );
      _startEmitters();
    });
  }

  void _startEmitters() {
    _stopEmitters(keepReconnect: true);

    _commentTimer = Timer.periodic(
      Duration(milliseconds: 1200 + _random.nextInt(2800)),
      (_) => _emitFakeComment(),
    );

    _likeTimer = Timer.periodic(
      Duration(milliseconds: 800 + _random.nextInt(1600)),
      (_) => _emitFakeLikes(),
    );

    _viewerTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _emitViewerUpdate(),
    );

    _giftTimer = Timer.periodic(
      Duration(seconds: 8 + _random.nextInt(12)),
      (_) => _emitFakeGift(),
    );

    _joinTimer = Timer.periodic(
      Duration(seconds: 4 + _random.nextInt(6)),
      (_) => _emitUserJoined(),
    );
  }

  void _stopEmitters({bool keepReconnect = false}) {
    _commentTimer?.cancel();
    _likeTimer?.cancel();
    _viewerTimer?.cancel();
    _giftTimer?.cancel();
    _joinTimer?.cancel();
    _endTimer?.cancel();
    _networkChaosTimer?.cancel();
    if (!keepReconnect) {
      _reconnectTimer?.cancel();
    }
  }

  void _emitFakeComment() {
    if (!_connected || _liveId == null) return;
    final username = _usernames[_random.nextInt(_usernames.length)];
    final comment = CommentEntity(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      liveId: _liveId!,
      userId: 'user_${_random.nextInt(99999)}',
      username: username,
      userAvatar: 'https://i.pravatar.cc/150?u=$username',
      content: _comments[_random.nextInt(_comments.length)],
      createdAt: DateTime.now(),
    );
    _controller.add(
      LiveCommentEvent(
        liveId: _liveId!,
        comment: comment,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _emitFakeLikes() {
    if (!_connected || _liveId == null) return;
    final delta = 1 + _random.nextInt(12);
    _likeCount += delta;
    _controller.add(
      LiveLikeEvent(
        liveId: _liveId!,
        likeCount: _likeCount,
        delta: delta,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _emitViewerUpdate() {
    if (!_connected || _liveId == null) return;
    final delta = _random.nextInt(21) - 8;
    _viewerCount = (_viewerCount + delta).clamp(1, 999999);
    _controller.add(
      LiveViewersEvent(
        liveId: _liveId!,
        viewerCount: _viewerCount,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _emitFakeGift() {
    if (!_connected || _liveId == null) return;
    final gift = MockGiftCatalog.random(_random);
    final username = _usernames[_random.nextInt(_usernames.length)];
    final qty = 1 + _random.nextInt(3);
    final sent = GiftSentEntity(
      id: 'g_${DateTime.now().microsecondsSinceEpoch}',
      giftId: gift.id,
      liveId: _liveId!,
      senderId: 'user_${_random.nextInt(99999)}',
      senderName: username,
      senderAvatar: 'https://i.pravatar.cc/150?u=$username',
      quantity: qty,
      totalCost: gift.coinCost * qty,
      sentAt: DateTime.now(),
      giftDetails: gift,
    );
    _controller.add(
      LiveGiftEvent(liveId: _liveId!, gift: sent, timestamp: DateTime.now()),
    );
  }

  void _emitUserJoined() {
    if (!_connected || _liveId == null) return;
    final username = _usernames[_random.nextInt(_usernames.length)];
    _viewerCount += 1;
    _controller.add(
      UserJoinedEvent(
        liveId: _liveId!,
        userId: 'user_${_random.nextInt(99999)}',
        username: username,
        avatarUrl: 'https://i.pravatar.cc/150?u=$username',
        timestamp: DateTime.now(),
      ),
    );
    _controller.add(
      LiveViewersEvent(
        liveId: _liveId!,
        viewerCount: _viewerCount,
        timestamp: DateTime.now(),
      ),
    );
  }

  void dispose() {
    _stopEmitters();
    _controller.close();
  }
}

/// Shared gift catalog used by socket + gift repository.
class MockGiftCatalog {
  MockGiftCatalog._();

  static final List<GiftEntity> gifts = [
    const GiftEntity(
      id: 'gift_rose',
      name: 'Rose',
      iconUrl: 'rose',
      coinCost: 1,
      rarity: GiftRarity.common,
      hasAnimation: true,
    ),
    const GiftEntity(
      id: 'gift_heart',
      name: 'Heart',
      iconUrl: 'heart',
      coinCost: 5,
      rarity: GiftRarity.common,
      hasAnimation: true,
    ),
    const GiftEntity(
      id: 'gift_teddy',
      name: 'Teddy',
      iconUrl: 'teddy',
      coinCost: 10,
      rarity: GiftRarity.uncommon,
      hasAnimation: true,
    ),
    const GiftEntity(
      id: 'gift_star',
      name: 'Star',
      iconUrl: 'star',
      coinCost: 20,
      rarity: GiftRarity.uncommon,
      hasAnimation: true,
    ),
    const GiftEntity(
      id: 'gift_cake',
      name: 'Cake',
      iconUrl: 'cake',
      coinCost: 30,
      rarity: GiftRarity.rare,
      hasAnimation: true,
    ),
    const GiftEntity(
      id: 'gift_crown',
      name: 'Crown',
      iconUrl: 'crown',
      coinCost: 50,
      rarity: GiftRarity.rare,
      hasAnimation: true,
    ),
    const GiftEntity(
      id: 'gift_diamond',
      name: 'Diamond',
      iconUrl: 'diamond',
      coinCost: 100,
      rarity: GiftRarity.epic,
      hasAnimation: true,
      durationMs: 2500,
    ),
    const GiftEntity(
      id: 'gift_rocket',
      name: 'Rocket',
      iconUrl: 'rocket',
      coinCost: 199,
      rarity: GiftRarity.epic,
      hasAnimation: true,
      durationMs: 3000,
    ),
    const GiftEntity(
      id: 'gift_ring',
      name: 'Ring',
      iconUrl: 'ring',
      coinCost: 299,
      rarity: GiftRarity.legendary,
      hasAnimation: true,
      durationMs: 3200,
    ),
    const GiftEntity(
      id: 'gift_car',
      name: 'Sports Car',
      iconUrl: 'car',
      coinCost: 500,
      rarity: GiftRarity.legendary,
      hasAnimation: true,
      durationMs: 3500,
    ),
    const GiftEntity(
      id: 'gift_castle',
      name: 'Castle',
      iconUrl: 'castle',
      coinCost: 1000,
      rarity: GiftRarity.mythic,
      hasAnimation: true,
      durationMs: 4000,
    ),
    const GiftEntity(
      id: 'gift_universe',
      name: 'Universe',
      iconUrl: 'universe',
      coinCost: 2999,
      rarity: GiftRarity.mythic,
      hasAnimation: true,
      durationMs: 4500,
    ),
  ];

  static GiftEntity random(Random random) {
    // Bias toward cheaper gifts.
    final weights = [30, 25, 15, 10, 8, 5, 3, 2, 1, 1, 0, 0];
    final total = weights.reduce((a, b) => a + b);
    var pick = random.nextInt(total);
    for (var i = 0; i < gifts.length; i++) {
      pick -= weights[i];
      if (pick < 0) return gifts[i];
    }
    return gifts.first;
  }

  static GiftEntity? byId(String id) {
    for (final g in gifts) {
      if (g.id == id) return g;
    }
    return null;
  }
}
