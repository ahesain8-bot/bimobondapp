import 'dart:async';

import 'package:bimobondapp/app/gifts/data/datasources/gift_catalog_hydrator.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/models/live_battle.dart';
import '../../domain/repositories/live_session_repository.dart';
import '../mappers/live_session_mapper.dart';

/// Socket.IO HUD client for `live_{id}` (lives/mobile-api.md §16).
class LivesSocketDataSource {
  LivesSocketDataSource({
    required Future<String?> Function() idTokenProvider,
  }) : _idTokenProvider = idTokenProvider;

  /// Legacy aliases retained for payload compatibility. Visual combo delivery
  /// is owned by the shared AuctionSocketService stream.
  static const giftEventNames = <String>[
    'gift_combo',
    'auctionGiftCombo',
    'liveGiftCombo',
    'liveGift',
  ];

  final Future<String?> Function() _idTokenProvider;

  io.Socket? _socket;
  String? _liveId;
  String? _desiredLiveId;
  Completer<void>? _connectionReady;
  bool _authRefreshInFlight = false;
  final Map<String, DateTime> _recentGiftEvents = {};
  final _controller = StreamController<LiveHudEvent>.broadcast();

  Stream<LiveHudEvent> get events => _controller.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connectAndJoin(String liveId) async {
    // A timed-out handshake may still reconnect successfully. Reuse it instead
    // of disposing the manager on every BLoC retry, which previously prevented
    // Socket.IO's own reconnection loop from ever completing.
    final existing = _socket;
    if (_liveId == liveId && existing != null) {
      if (existing.connected) return;
      existing.connect();
      final signal = _connectionReady;
      if (signal != null) {
        await signal.future.timeout(const Duration(seconds: 10));
        return;
      }
    }

    await disconnect();
    _desiredLiveId = liveId;
    _liveId = liveId;

    final token = await _idTokenProvider();
    if (token == null || token.isEmpty) {
      throw StateError('Missing Firebase ID token for Socket.IO auth');
    }

    final socket = io.io(
      ApiEndpoints.baseUrl,
      io.OptionBuilder()
          // Every feature opens the same namespace on the same API host. Force
          // a manager here so an older notification/chat socket cannot donate
          // stale auth/options or be disconnected when the live room leaves.
          .enableForceNew()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(6)
          .setTimeout(8000)
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket = socket;
    final connected = Completer<void>();
    _connectionReady = connected;

    socket.onConnect((_) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('Socket.IO connected');
      _joinRooms(socket, liveId);
      if (!connected.isCompleted) connected.complete();
      _controller.add(const LiveHudConnectionEvent(connected: true));
    });

    socket.onDisconnect((_) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('Socket.IO disconnected');
      _controller.add(
        const LiveHudConnectionEvent(connected: false, reason: 'disconnected'),
      );
    });
    socket.onConnectError((e) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('Socket.IO connect error: $e');
      // Do not complete the handshake with an error: automatic reconnection is
      // still active and may succeed on polling or the next network attempt.
      _controller.add(
        LiveHudConnectionEvent(connected: false, reason: e.toString()),
      );
    });
    socket.onError((e) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('Socket.IO error: $e');
      _controller.add(
        LiveHudConnectionEvent(connected: false, reason: e.toString()),
      );
    });

    socket.onReconnect((_) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('Socket.IO reconnected; rejoining live room');
      _joinRooms(socket, liveId);
      if (!connected.isCompleted) connected.complete();
      _controller.add(const LiveHudConnectionEvent(connected: true));
    });

    socket.onReconnectAttempt((attempt) {
      if (_socket != socket || _liveId != liveId) return;
      _controller.add(
        LiveHudConnectionEvent(
          connected: false,
          reason: 'reconnecting ($attempt)',
        ),
      );
    });
    socket.onReconnectFailed((_) {
      if (_socket != socket || _liveId != liveId) return;
      _controller.add(
        const LiveHudConnectionEvent(
          connected: false,
          reason: 'refreshing authentication',
        ),
      );
      unawaited(_rebuildWithFreshAuth(socket, liveId));
    });

    _on(socket, 'liveComment', (data) {
      final map = _asMap(data);
      if (map == null) return;
      _controller.add(
        LiveHudCommentEvent(LiveSessionMapper.commentFromJson(map)),
      );
    });

    _on(socket, 'liveCommentDeleted', (data) {
      final map = _asMap(data);
      final id = map?['commentId']?.toString();
      if (id != null) {
        _controller.add(LiveHudCommentDeletedEvent(id));
      }
    });

    _on(socket, 'liveCommentPinned', (data) {
      final map = _asMap(data);
      if (map == null) return;
      _controller.add(
        LiveHudCommentPinnedEvent(LiveSessionMapper.commentFromJson(map)),
      );
    });

    _on(socket, 'liveCommentUnpinned', (data) {
      final map = _asMap(data);
      final id = map?['commentId']?.toString();
      if (id != null) {
        _controller.add(LiveHudCommentUnpinnedEvent(id));
      }
    });

    _on(socket, 'liveModeration', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final type = map['type']?.toString();
      if (type == null || type.isEmpty) return;
      _controller.add(
        LiveHudModerationEvent(
          type: type,
          liveId: map['liveId']?.toString() ?? liveId,
          userId: map['userId']?.toString(),
          reason: map['reason']?.toString(),
        ),
      );
    });

    _on(socket, 'liveViewers', (data) {
      final map = _asMap(data);
      final rawViewers =
          map?['viewers'] ??
          map?['viewerCount'] ??
          map?['viewer_count'] ??
          map?['count'];
      final viewers =
          _asInt(rawViewers) ?? (rawViewers is List ? rawViewers.length : null);
      if (viewers != null) {
        _controller.add(LiveHudViewersEvent(viewers));
      }
    });

    _on(socket, 'userJoined', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final user = _asMap(map['user']) ?? map;
      final userId = user['id']?.toString() ?? map['userId']?.toString();
      if (userId == null || userId.isEmpty) return;
      _controller.add(
        LiveHudUserJoinedEvent(
          userId: userId,
          username:
              user['username']?.toString() ??
              user['fullName']?.toString() ??
              'مشاهد',
          avatarUrl:
              user['avatarUrl']?.toString() ?? user['avatar']?.toString(),
          viewers: _asInt(
            map['viewers'] ??
                map['viewerCount'] ??
                map['viewer_count'] ??
                map['count'],
          ),
        ),
      );
    });

    _on(socket, 'liveLike', (data) {
      final map = _asMap(data);
      final likeCount = _asInt(map?['likeCount']);
      if (likeCount != null) {
        _controller.add(
          LiveHudLikeEvent(
            likeCount: likeCount,
            userId: map?['userId']?.toString(),
          ),
        );
      }
    });

    _on(socket, 'liveEnded', (data) {
      final map = _asMap(data);
      _controller.add(
        LiveHudEndedEvent(
          liveId: map?['liveId']?.toString() ?? liveId,
          status: map?['status']?.toString(),
          reason: map?['reason']?.toString(),
        ),
      );
    });

    // Visual gift combos are owned by the shared AuctionSocketService now.
    // Keep the legacy liveGift callback only for old display/comment payloads;
    // rich combo payloads are ignored here so the host has one visual owner.
    _on(socket, 'liveGift', (data) {
      _handleGiftPayload(
        data,
        fallbackLiveId: liveId,
        sourceEvent: 'liveGift',
      );
    });

    // Personal room `user_*`, not the live room: an invite can land while the
    // user is watching something else entirely (mobile-api.md, Personal room).
    _on(socket, 'liveGuestInvite', (data) {
      final map = _asMap(data);
      final host = _asMap(map?['host']) ?? _asMap(map?['user']);
      final fullName = host?['fullName']?.toString();
      _controller.add(
        LiveHudGuestInviteEvent(
          liveId: map?['liveId']?.toString(),
          hostName: (fullName != null && fullName.trim().isNotEmpty)
              ? fullName.trim()
              : (host?['username']?.toString() ?? map?['hostName']?.toString()),
          role: (map?['role'] ?? map?['guestRole'])?.toString(),
        ),
      );
    });

    // Stage changes (mobile-api.md §16): a guest was invited, joined, left,
    // was kicked, muted or had their role changed — plus `settings` when the
    // host edits the multi-guest policy. Without this the room never learns
    // anyone came on stage.
    _on(socket, 'liveGuestUpdate', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final type = map['type']?.toString();
      if (type == null || type.isEmpty) return;
      _controller.add(
        LiveHudGuestUpdateEvent(
          type: type,
          liveId: map['liveId']?.toString() ?? liveId,
          guest: _asMap(map['guest']),
          settings: _asMap(map['settings']),
        ),
      );
    });

    void battleEvent(dynamic data, String fallbackType) {
      final map = _unwrapPayload(data) ?? _asMap(data);
      if (map == null) return;
      final raw = _asMap(map['battle']) ?? map;
      if (raw['id'] == null) return;
      _controller.add(
        LiveHudBattleEvent(
          type: map['type']?.toString() ?? fallbackType,
          battle: LiveBattle.fromJson(raw),
        ),
      );
    }

    _on(socket, 'liveBattle', (data) => battleEvent(data, 'score'));
    _on(socket, 'liveBattlePhase', (data) => battleEvent(data, 'phase'));

    _on(socket, 'liveHourlyRankUpdated', (data) {
      final map = _asMap(data);
      final rank = _asInt(map?['hourlyRank'] ?? map?['rank']);
      _controller.add(
        LiveHudHourlyRankEvent(
          hourlyRank: rank,
          label: rank != null ? 'ترتيب #$rank' : null,
        ),
      );
    });

    socket.connect();
    await connected.future.timeout(const Duration(seconds: 10));
  }

  Future<void> disconnect() async {
    final socket = _socket;
    final liveId = _liveId;
    _socket = null;
    _liveId = null;
    _desiredLiveId = null;
    _connectionReady = null;
    _recentGiftEvents.clear();
    if (socket != null) {
      if (liveId != null) {
        socket.emit('leaveLive', {'liveId': liveId});
      }
      socket.dispose();
    }
  }

  /// A Socket.IO manager keeps the auth map it was created with. After the
  /// Firebase JWT expires, infinite reconnects therefore repeat the same 401
  /// forever. Rebuild the manager after a bounded cycle so the provider can
  /// supply a fresh token, while still retrying until the host leaves.
  Future<void> _rebuildWithFreshAuth(io.Socket stale, String liveId) async {
    if (_authRefreshInFlight || _socket != stale || _liveId != liveId) return;
    _authRefreshInFlight = true;
    try {
      stale.dispose();
      if (_socket == stale) {
        _socket = null;
        _liveId = null;
        _connectionReady = null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (_desiredLiveId != liveId ||
          _socket != null ||
          (_liveId != null && _liveId != liveId)) {
        return;
      }
      await connectAndJoin(liveId);
    } catch (e) {
      debugPrint('Socket.IO fresh-auth reconnect failed: $e');
    } finally {
      _authRefreshInFlight = false;
    }
  }

  void _joinRooms(io.Socket socket, String liveId) {
    socket.emit('joinLive', {'liveId': liveId});
    socket.emit('joinUser', {});
  }

  void _handleGiftPayload(
    dynamic data, {
    required String fallbackLiveId,
    required String sourceEvent,
  }) {
    unawaited(
      _handleGiftPayloadAsync(
        data,
        fallbackLiveId: fallbackLiveId,
        sourceEvent: sourceEvent,
      ).catchError((error, stack) {
        debugPrint('Socket.IO gift payload failed: $error\n$stack');
      }),
    );
  }

  Future<void> _handleGiftPayloadAsync(
    dynamic data, {
    required String fallbackLiveId,
    required String sourceEvent,
  }) async {
    final map = _unwrapPayload(data);
    if (map == null) return;
    map.putIfAbsent('liveId', () => fallbackLiveId);

    final sender = _asMap(map['sender']) ?? _asMap(map['user']);
    final gift = _asMap(map['gift']);
    if (sender != null) map.putIfAbsent('sender', () => sender);
    final giftId = map['giftId']?.toString() ?? gift?['id']?.toString();
    if (giftId != null && giftId.isNotEmpty) {
      map.putIfAbsent('giftId', () => giftId);
    }

    // Rich visual combo payloads are parsed by the shared
    // AuctionSocketService.onGiftCombo stream instead.
    if (giftId != null && giftId.isNotEmpty) {
      // The canonical AuctionSocketService.onGiftCombo subscription feeds
      // LiveRoomBloc.latestGiftCombo. Do not forward this alias into the HUD
      // stream, otherwise the active host could render the same gift twice.
      return;
    }

    if (_isDuplicateGiftEvent(map, sourceEvent: sourceEvent)) return;

    // Very old payloads carried only display fields. Keep a banner/chat
    // fallback so the host still sees that a gift arrived.
    final senderName =
        sender?['fullName']?.toString() ??
        sender?['username']?.toString() ??
        map['senderName']?.toString();
    _controller.add(
      LiveHudGiftEvent(
        summaryText: map['summaryText']?.toString(),
        totalEarnedCoins: _asInt(map['totalEarnedCoins']),
        senderName: senderName,
        senderGifterLevel: _asInt(
          sender?['gifterLevel'] ?? map['senderGifterLevel'],
        ),
        senderAvatarUrl:
            sender?['avatarUrl']?.toString() ??
            map['senderAvatarUrl']?.toString(),
        giftName: gift?['name']?.toString() ?? map['giftName']?.toString(),
        giftIcon: gift?['icon']?.toString() ?? map['giftIcon']?.toString(),
        giftImageUrl:
            gift?['imageUrl']?.toString() ??
            gift?['iconUrl']?.toString() ??
            map['giftImageUrl']?.toString(),
        quantity: _asInt(map['quantity'] ?? map['qty']) ?? 1,
      ),
    );
  }

  bool _isDuplicateGiftEvent(
    Map<String, dynamic> map, {
    required String sourceEvent,
  }) {
    final now = DateTime.now();
    _recentGiftEvents.removeWhere(
      (_, seenAt) => now.difference(seenAt) > const Duration(seconds: 4),
    );

    // De-duplicate repeats from the same socket event only. A metadata-poor
    // liveGift must not suppress a richer auctionGiftCombo for the same
    // transaction; FloatingGiftsLayer performs the final presentation-level
    // de-duplication after both aliases reach the canonical combo pipeline.
    final key = '$sourceEvent:${_giftEventKey(map)}';
    final previous = _recentGiftEvents[key];
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 2)) {
      return true;
    }
    _recentGiftEvents[key] = now;
    return false;
  }

  /// Merges catalog presentation fields into a flat socket payload.
  ///
  /// Hydration itself is owned by [GiftCatalogHydrator], which the shared
  /// `AuctionSocketService.onGiftCombo` stream applies before any listener sees
  /// the payload.
  static Map<String, dynamic> enrichGiftPayloadWithCatalog(
    Map<String, dynamic> payload,
    GiftEntity catalogGift,
  ) => GiftCatalogHydrator.enrich(payload, catalogGift);

  String _giftEventKey(Map<String, dynamic> map) {
    final gift = _asMap(map['gift']);
    final sender = _asMap(map['sender']) ?? _asMap(map['user']);
    final transaction =
        map['transactionId'] ?? map['transaction_id'] ?? map['tx'] ?? map['id'];
    if (transaction != null && transaction.toString().isNotEmpty) {
      return 'tx:${transaction.toString()}:'
          '${map['combo'] ?? map['quantity'] ?? map['qty'] ?? 1}';
    }
    return 'gift:${map['liveId']}:${sender?['id'] ?? map['senderId']}:'
        '${gift?['id'] ?? map['giftId']}:${map['combo'] ?? map['quantity'] ?? 1}';
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }

  /// Registers [handler] so a throw inside it is logged instead of killing
  /// delivery. Socket.IO swallows the error, and the symptom is a feed that
  /// silently stops updating for the rest of the session.
  void _on(
    io.Socket socket,
    String event,
    void Function(dynamic data) handler,
  ) {
    socket.on(event, (data) {
      try {
        handler(data);
      } catch (e, stack) {
        debugPrint('Socket.IO handler for "$event" threw: $e\n$stack');
      }
    });
  }

  /// Nested objects are converted too: the payload arrives as `Map<dynamic,
  /// dynamic>` on some transports, and a shallow copy left `map['user']`
  /// un-castable further down the mapper.
  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is! Map) return null;
    return data.map((key, value) => MapEntry(key.toString(), _deep(value)));
  }

  dynamic _deep(dynamic value) {
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), _deep(v)));
    }
    if (value is List) return value.map(_deep).toList();
    return value;
  }

  Map<String, dynamic>? _unwrapPayload(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return _unwrapPayload(data.first);
    }
    final map = _asMap(data);
    if (map == null) return null;

    final nested = _asMap(map['data']);
    if (nested != null &&
        (map.containsKey('event') ||
            (!map.containsKey('giftId') && !map.containsKey('gift')))) {
      return nested;
    }
    return map;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
