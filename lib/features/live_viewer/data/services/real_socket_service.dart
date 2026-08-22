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
/// liveLike, liveViewers, liveEnded, userJoined + reconnect lifecycle.
class RealSocketService implements SocketService {
  RealSocketService({Future<String?> Function()? idTokenProvider})
    : _idTokenProvider = idTokenProvider ?? _defaultTokenProvider;

  final Future<String?> Function() _idTokenProvider;

  static Future<String?> _defaultTokenProvider() async {
    return null;
  }

  io.Socket? _socket;
  String? _liveId;
  bool _connected = false;
  final _controller = StreamController<SocketEvent>.broadcast();

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  String? get currentLiveId => _liveId;

  @override
  Future<void> connect({required String liveId, required String token}) async {
    await disconnect();

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
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': authToken})
          .setExtraHeaders({'Authorization': 'Bearer $authToken'})
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      debugPrint('🔌 Live viewer socket connected');
      _connected = true;
      socket.emit('joinLive', {'liveId': liveId});
      socket.emit('joinUser', {});
    });

    socket.onDisconnect((_) {
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
      debugPrint('⚠️ Live viewer socket connect error: $e');
      _connected = false;
    });

    socket.onError((e) {
      debugPrint('⚠️ Live viewer socket error: $e');
    });

    socket.onReconnectAttempt((attempt) {
      if (_liveId == null) return;
      _controller.add(
        ReconnectingEvent(
          liveId: _liveId!,
          attempt: attempt,
          timestamp: DateTime.now(),
        ),
      );
    });

    socket.onReconnect((_) {
      _connected = true;
      if (_liveId != null) {
        socket.emit('joinLive', {'liveId': _liveId});
        _controller.add(
          ReconnectedEvent(liveId: _liveId!, timestamp: DateTime.now()),
        );
      }
    });

    socket.on('liveComment', (data) {
      final event = SocketMapper.commentEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveCommentDeleted', (data) {
      final event = SocketMapper.commentDeletedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveCommentPinned', (data) {
      final event = SocketMapper.commentPinnedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveCommentUnpinned', (data) {
      final event = SocketMapper.commentUnpinnedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveModeration', (data) {
      final event = SocketMapper.moderationEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveGift', (data) {
      final event = SocketMapper.giftEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveLike', (data) {
      final event = SocketMapper.likeEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveViewers', (data) {
      final event = SocketMapper.viewersEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('liveEnded', (data) {
      final event = SocketMapper.endedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.on('userJoined', (data) {
      final event = SocketMapper.userJoinedEvent(data, _liveId);
      if (event != null) _controller.add(event);
    });

    socket.connect();
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    final liveId = _liveId;
    _socket = null;
    _liveId = null;
    _connected = false;
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
