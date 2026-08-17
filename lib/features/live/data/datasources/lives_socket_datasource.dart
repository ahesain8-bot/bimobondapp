import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/network/api_endpoints.dart';
import '../../domain/repositories/live_session_repository.dart';
import '../mappers/live_session_mapper.dart';

/// Socket.IO HUD client for `live_{id}` (lives/mobile-api.md §16).
class LivesSocketDataSource {
  LivesSocketDataSource({
    required Future<String?> Function() idTokenProvider,
  }) : _idTokenProvider = idTokenProvider;

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

    socket.onConnect((_) {
      debugPrint('Socket.IO connected');
      socket.emit('joinLive', {'liveId': liveId});
      socket.emit('joinUser', {});
    });

    socket.onDisconnect((_) => debugPrint('Socket.IO disconnected'));
    socket.onConnectError((e) => debugPrint('Socket.IO connect error: $e'));
    socket.onError((e) => debugPrint('Socket.IO error: $e'));

    socket.on('liveComment', (data) {
      final map = _asMap(data);
      if (map == null) return;
      _controller.add(
        LiveHudCommentEvent(LiveSessionMapper.commentFromJson(map)),
      );
    });

    socket.on('liveCommentDeleted', (data) {
      final map = _asMap(data);
      final id = map?['commentId']?.toString();
      if (id != null) {
        _controller.add(LiveHudCommentDeletedEvent(id));
      }
    });

    socket.on('liveCommentPinned', (data) {
      final map = _asMap(data);
      if (map == null) return;
      _controller.add(
        LiveHudCommentPinnedEvent(LiveSessionMapper.commentFromJson(map)),
      );
    });

    socket.on('liveCommentUnpinned', (data) {
      final map = _asMap(data);
      final id = map?['commentId']?.toString();
      if (id != null) {
        _controller.add(LiveHudCommentUnpinnedEvent(id));
      }
    });

    socket.on('liveModeration', (data) {
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

    socket.on('liveViewers', (data) {
      final map = _asMap(data);
      final viewers = _asInt(map?['viewers']);
      if (viewers != null) {
        _controller.add(LiveHudViewersEvent(viewers));
      }
    });

    socket.on('liveLike', (data) {
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

    socket.on('liveEnded', (data) {
      final map = _asMap(data);
      _controller.add(
        LiveHudEndedEvent(
          liveId: map?['liveId']?.toString() ?? liveId,
          status: map?['status']?.toString(),
          reason: map?['reason']?.toString(),
        ),
      );
    });

    socket.on('liveGift', (data) {
      final map = _asMap(data);
      final sender = _asMap(map?['sender']) ?? _asMap(map?['user']);
      _controller.add(
        LiveHudGiftEvent(
          summaryText: map?['message']?.toString() ??
              map?['summary']?.toString(),
          totalEarnedCoins: _asInt(map?['totalEarnedCoins']),
          senderName: sender?['username']?.toString() ??
              sender?['fullName']?.toString() ??
              map?['senderName']?.toString(),
          senderGifterLevel: _asInt(sender?['gifterLevel']),
        ),
      );
    });

    socket.on('liveHourlyRankUpdated', (data) {
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

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
