import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/network/api_endpoints.dart';
import '../../domain/repositories/live_session_repository.dart';
import '../mappers/live_session_mapper.dart';

/// Socket.IO HUD client for `live_{id}` (lives/mobile-api.md §16).
class LivesSocketDataSource {
  LivesSocketDataSource({required Future<String?> Function() idTokenProvider})
    : _idTokenProvider = idTokenProvider;

  final Future<String?> Function() _idTokenProvider;

  io.Socket? _socket;
  String? _liveId;
  final _controller = StreamController<LiveHudEvent>.broadcast();

  Stream<LiveHudEvent> get events => _controller.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connectAndJoin(String liveId) async {
    await disconnect();
    _liveId = liveId;

    final token = await _idTokenProvider();
    if (token == null || token.isEmpty) {
      throw StateError('Missing Firebase ID token for Socket.IO auth');
    }

    final socket = io.io(
      ApiEndpoints.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket = socket;
    final connected = Completer<void>();

    socket.onConnect((_) {
      debugPrint('Socket.IO connected');
      socket.emit('joinLive', {'liveId': liveId});
      socket.emit('joinUser', {});
      if (!connected.isCompleted) connected.complete();
      _controller.add(const LiveHudConnectionEvent(connected: true));
    });

    socket.onDisconnect((_) {
      debugPrint('Socket.IO disconnected');
      _controller.add(
        const LiveHudConnectionEvent(connected: false, reason: 'disconnected'),
      );
    });
    socket.onConnectError((e) {
      debugPrint('Socket.IO connect error: $e');
      if (!connected.isCompleted) {
        connected.completeError(StateError('Socket.IO connect error: $e'));
      }
      _controller.add(
        LiveHudConnectionEvent(connected: false, reason: e.toString()),
      );
    });
    socket.onError((e) {
      debugPrint('Socket.IO error: $e');
      _controller.add(
        LiveHudConnectionEvent(connected: false, reason: e.toString()),
      );
    });

    socket.onReconnect((_) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('Socket.IO reconnected; rejoining live room');
      socket.emit('joinLive', {'liveId': liveId});
      socket.emit('joinUser', {});
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

    // `gift_combo` is the canonical live gift presentation event. The
    // legacy `liveGift` alias is intentionally not consumed here: parsing
    // both would show the same gift twice and route it through the old text
    // banner path.
    _on(socket, 'gift_combo', (data) {
      final map = _unwrapPayload(data);
      if (map == null) return;
      _controller.add(
        LiveHudGiftComboEvent(
          payload: map,
          totalEarnedCoins: _asInt(map['totalEarnedCoins']),
        ),
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
    if (socket != null) {
      if (liveId != null) {
        socket.emit('leaveLive', {'liveId': liveId});
      }
      socket.dispose();
    }
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
