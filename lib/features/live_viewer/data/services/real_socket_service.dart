import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/socket_event.dart';
import '../mappers/socket_mapper.dart';
import 'fake_socket_service.dart' show SocketService;

/// Real Socket.IO implementation of [SocketService].
///
/// Connects with the Firebase ID token (lives/mobile-api.md §16):
/// ```js
/// io(API_BASE_URL, { auth: { token: firebaseIdToken },
///                    extraHeaders: { Authorization: Bearer <token> } })
/// ```
/// Client → server: `joinLive { liveId }` / `leaveLive { liveId }`.
/// Server → client (`live_{id}`): liveComment, liveCommentDeleted,
/// liveCommentPinned, liveCommentUnpinned, liveModeration, liveGift,
/// liveLike, liveViewers, liveEnded, userJoined, liveHourlyRankUpdated,
/// livePopularStatus + reconnect lifecycle.
class RealSocketService implements SocketService {
  RealSocketService({Future<String?> Function()? idTokenProvider})
    : _idTokenProvider = idTokenProvider ?? _defaultTokenProvider;

  final Future<String?> Function() _idTokenProvider;

  static Future<String?> _defaultTokenProvider() async {
    return null;
  }

  io.Socket? _socket;
  String? _liveId;
  String? _desiredLiveId;
  bool _connected = false;
  Completer<void>? _connectionReady;
  bool _authRefreshInFlight = false;
  final _controller = StreamController<SocketEvent>.broadcast();

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  String? get currentLiveId => _liveId;

  @override
  Future<void> connect({required String liveId, required String token}) async {
    // Let Socket.IO finish its own reconnect rather than replacing the manager
    // every time the caller retries a handshake.
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

    final fbToken = await _idTokenProvider();
    final authToken = (fbToken != null && fbToken.isNotEmpty)
        ? fbToken
        : (token.isNotEmpty ? token : null);

    if (authToken == null) {
      throw StateError('Missing Firebase ID token for Socket.IO auth');
    }

    final socket = io.io(
      ApiEndpoints.baseUrl,
      io.OptionBuilder()
          // Other app features connect to the same host/namespace. A private
          // manager prevents stale auth and disconnects from leaking between
          // chat, notifications and a live room.
          .enableForceNew()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(6)
          .setTimeout(8000)
          .disableAutoConnect()
          .setAuth({'token': authToken})
          .setExtraHeaders({'Authorization': 'Bearer $authToken'})
          .build(),
    );

    _socket = socket;
    final connected = Completer<void>();
    _connectionReady = connected;

    socket.onConnect((_) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('🔌 Live viewer socket connected');
      _connected = true;
      _joinRooms(socket, liveId);
      if (!connected.isCompleted) connected.complete();
      _controller.add(
        ReconnectedEvent(liveId: liveId, timestamp: DateTime.now()),
      );
    });

    socket.onDisconnect((_) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('🔌 Live viewer socket disconnected');
      final wasConnected = _connected;
      _connected = false;
      if (wasConnected && _liveId != null) {
        _controller.add(
          NetworkLostEvent(liveId: _liveId!, timestamp: DateTime.now()),
        );
      }
    });

    socket.onConnectError((e) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('⚠️ Live viewer socket connect error: $e');
      _connected = false;
      // Automatic reconnection is still running. Keep the handshake pending
      // so a polling fallback or the next network attempt can complete it.
    });

    socket.onError((e) {
      if (_socket != socket || _liveId != liveId) return;
      debugPrint('⚠️ Live viewer socket error: $e');
    });

    socket.onReconnectAttempt((attempt) {
      if (_socket != socket || _liveId != liveId) return;
      _controller.add(
        ReconnectingEvent(
          liveId: liveId,
          attempt: attempt,
          timestamp: DateTime.now(),
        ),
      );
    });

    socket.onReconnect((_) {
      if (_socket != socket || _liveId != liveId) return;
      _connected = true;
      _joinRooms(socket, liveId);
      if (!connected.isCompleted) connected.complete();
    });

    socket.onReconnectFailed((_) {
      if (_socket != socket || _liveId != liveId) return;
      unawaited(_rebuildWithFreshAuth(socket, liveId, token));
    });

    _on(socket, 'liveComment', (data) {
      final event = SocketMapper.commentEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveCommentDeleted', (data) {
      final event = SocketMapper.commentDeletedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveCommentPinned', (data) {
      final event = SocketMapper.commentPinnedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveCommentUnpinned', (data) {
      final event = SocketMapper.commentUnpinnedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveModeration', (data) {
      final event = SocketMapper.moderationEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveGift', (data) {
      final event = SocketMapper.giftEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveLike', (data) {
      final event = SocketMapper.likeEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveViewers', (data) {
      final event = SocketMapper.viewersEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveEnded', (data) {
      final event = SocketMapper.endedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'userJoined', (data) {
      final event = SocketMapper.userJoinedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    // Stage events. The invite rides the personal `user_*` room, the update
    // rides `live_{id}` — neither was listened for, so a viewer could be put on
    // stage by the host and never find out.
    _on(socket, 'liveGuestInvite', (data) {
      final event = SocketMapper.guestInviteEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveGuestUpdate', (data) {
      final event = SocketMapper.guestUpdateEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveBattle', (data) {
      final event = SocketMapper.battleEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'liveBattlePhase', (data) {
      final event = SocketMapper.battleEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    // Hourly ranking moves as gifts land, so the rank shown in the ranking
    // sheet must not be frozen at whatever it was when the sheet opened.
    _on(socket, 'liveHourlyRankUpdated', (data) {
      final event = SocketMapper.hourlyRankEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    _on(socket, 'livePopularStatus', (data) {
      final event = SocketMapper.hourlyRankEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.connect();
    await connected.future.timeout(const Duration(seconds: 10));
  }

  void _joinRooms(io.Socket socket, String liveId) {
    socket.emit('joinLive', {'liveId': liveId});
    socket.emit('joinUser', {});
  }

  Future<void> _rebuildWithFreshAuth(
    io.Socket stale,
    String liveId,
    String fallbackToken,
  ) async {
    if (_authRefreshInFlight || _socket != stale || _liveId != liveId) return;
    _authRefreshInFlight = true;
    try {
      stale.dispose();
      if (_socket == stale) {
        _socket = null;
        _liveId = null;
        _connected = false;
        _connectionReady = null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (_desiredLiveId != liveId ||
          _socket != null ||
          (_liveId != null && _liveId != liveId)) {
        return;
      }
      await connect(liveId: liveId, token: fallbackToken);
    } catch (e) {
      debugPrint('Live viewer socket fresh-auth reconnect failed: $e');
    } finally {
      _authRefreshInFlight = false;
    }
  }

  /// Registers [handler] so a throw inside it is logged instead of silently
  /// ending delivery for that event.
  void _on(
    io.Socket socket,
    String event,
    void Function(dynamic data) handler,
  ) {
    socket.on(event, (data) {
      try {
        handler(data);
      } catch (e, stack) {
        debugPrint('⚠️ Live viewer socket "$event" handler threw: $e\n$stack');
      }
    });
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    final liveId = _liveId;
    _socket = null;
    _liveId = null;
    _desiredLiveId = null;
    _connected = false;
    _connectionReady = null;
    if (socket != null) {
      if (liveId != null) {
        try {
          socket.emit('leaveLive', {'liveId': liveId});
        } catch (_) {}
      }
      socket.dispose();
    }
  }

  @override
  Future<void> emitComment(CommentEntity comment) async {
    // Comments are sent over HTTP (POST /lives/:id/comments) in the real
    // implementation — the socket is receive-only for the viewer.
  }

  @override
  Future<void> emitLike({required int likeCount, int delta = 1}) async {
    // Likes are sent over HTTP (POST /lives/:id/like) — receive-only here.
  }

  @override
  Future<void> emitGift(GiftSentEntity gift) async {
    // Gifts are sent over HTTP (POST /gifts/send) — receive-only here.
  }

  @override
  void simulateNetworkLoss() {
    // Not supported for the real socket — UI triggers a manual reconnect.
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}
