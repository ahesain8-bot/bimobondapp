import 'dart:async';
import 'dart:developer' as developer;

import 'package:bimobondapp/app/posts/data/models/comment_model.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket.io events for auction/post realtime (see AUCTION_COMMENT_REALTIME.md).
class AuctionSocketEvent {
  AuctionSocketEvent._();

  static const joinAuction = 'joinAuction';
  static const leaveAuction = 'leaveAuction';
  static const joinPost = 'joinPost';
  static const leavePost = 'leavePost';

  static const auctionUpdated = 'auctionUpdated';
  static const newComment = 'newComment';
}

class AuctionUpdatedPayload {
  const AuctionUpdatedPayload({
    this.auctionId,
    this.postId,
    this.currentTotalCoins,
    this.targetPriceCoins,
    this.startingPriceCoins,
    this.status,
    this.winnerId,
    this.lastComment,
    this.lastGift,
  });

  final String? auctionId;
  final String? postId;
  final int? currentTotalCoins;
  final int? targetPriceCoins;
  final int? startingPriceCoins;
  final String? status;
  final String? winnerId;
  final CommentModel? lastComment;
  final Map<String, dynamic>? lastGift;

  bool get hasGiftActivity => lastGift != null && lastGift!.isNotEmpty;
}

class AuctionSocketService {
  io.Socket? _socket;
  String? _joinedAuctionId;
  String? _joinedPostId;
  bool _connecting = false;

  final _auctionUpdatedController =
      StreamController<AuctionUpdatedPayload>.broadcast();
  final _newCommentController = StreamController<CommentModel>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<AuctionUpdatedPayload> get onAuctionUpdated =>
      _auctionUpdatedController.stream;
  Stream<CommentModel> get onNewComment => _newCommentController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket?.connected == true) {
      _rejoinRooms();
      return;
    }
    if (_connecting) {
      // Wait briefly for in-flight connect.
      for (var i = 0; i < 40 && _connecting; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (_socket?.connected == true) {
          _rejoinRooms();
          return;
        }
      }
    }

    _connecting = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : null;

      _socket?.dispose();
      _socket = io.io(
        ApiConstants.baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .enableReconnection()
            .disableAutoConnect()
            .setAuth(token != null ? {'token': token} : {})
            .setExtraHeaders(
              token != null ? {'Authorization': 'Bearer $token'} : {},
            )
            .build(),
      );

      final connected = Completer<void>();

      _socket!
        ..onConnect((_) {
          developer.log('AuctionSocket connected', name: 'AuctionSocket');
          _connectionController.add(true);
          _rejoinRooms();
          if (!connected.isCompleted) connected.complete();
        })
        ..onReconnect((_) {
          developer.log('AuctionSocket reconnected', name: 'AuctionSocket');
          _connectionController.add(true);
          _rejoinRooms();
        })
        ..onDisconnect((_) {
          developer.log('AuctionSocket disconnected', name: 'AuctionSocket');
          _connectionController.add(false);
        })
        ..onConnectError((err) {
          developer.log(
            'AuctionSocket connect error: $err',
            name: 'AuctionSocket',
          );
          if (!connected.isCompleted) connected.complete();
        })
        ..on(AuctionSocketEvent.auctionUpdated, _handleAuctionUpdated)
        ..on(AuctionSocketEvent.newComment, _handleNewComment);

      _socket!.connect();

      try {
        await connected.future.timeout(const Duration(seconds: 12));
      } catch (_) {
        // Joins retry on reconnect via _rejoinRooms().
      }
    } finally {
      _connecting = false;
    }
  }

  void joinAuction(String auctionId) {
    if (auctionId.isEmpty) return;
    _joinedAuctionId = auctionId;
    _emitJoinAuction(auctionId);
  }

  void leaveAuction(String auctionId) {
    if (auctionId.isEmpty) return;
    if (_joinedAuctionId == auctionId) {
      _joinedAuctionId = null;
    }
    if (_socket?.connected == true) {
      _socket?.emit(AuctionSocketEvent.leaveAuction, {'auctionId': auctionId});
    }
  }

  void joinPost(String postId) {
    if (postId.isEmpty) return;
    _joinedPostId = postId;
    _emitJoinPost(postId);
  }

  void leavePost(String postId) {
    if (postId.isEmpty) return;
    if (_joinedPostId == postId) {
      _joinedPostId = null;
    }
    if (_socket?.connected == true) {
      _socket?.emit(AuctionSocketEvent.leavePost, {'postId': postId});
    }
  }

  /// Stores target rooms and connects (or rejoins if already online).
  Future<void> ensureJoined({String? postId, String? auctionId}) async {
    if (postId != null && postId.isNotEmpty) {
      _joinedPostId = postId;
    }
    if (auctionId != null && auctionId.isNotEmpty) {
      _joinedAuctionId = auctionId;
    }
    await connect();
    _rejoinRooms();
  }

  void _emitJoinPost(String postId) {
    if (_socket?.connected != true) return;
    _socket!.emit(AuctionSocketEvent.joinPost, {'postId': postId});
    developer.log('AuctionSocket joinPost $postId', name: 'AuctionSocket');
  }

  void _emitJoinAuction(String auctionId) {
    if (_socket?.connected != true) return;
    _socket!.emit(AuctionSocketEvent.joinAuction, {'auctionId': auctionId});
    developer.log(
      'AuctionSocket joinAuction $auctionId',
      name: 'AuctionSocket',
    );
  }

  void _rejoinRooms() {
    final postId = _joinedPostId;
    if (postId != null && postId.isNotEmpty) {
      _emitJoinPost(postId);
    }
    final auctionId = _joinedAuctionId;
    if (auctionId != null && auctionId.isNotEmpty) {
      _emitJoinAuction(auctionId);
    }
  }

  void _handleNewComment(dynamic data) {
    final comment = _parseCommentPayload(data);
    if (comment == null) {
      developer.log(
        'AuctionSocket newComment parse failed: $data',
        name: 'AuctionSocket',
      );
      return;
    }
    developer.log(
      'AuctionSocket newComment ${comment.id} gift=${comment.isGift}',
      name: 'AuctionSocket',
    );
    if (!_newCommentController.isClosed) {
      _newCommentController.add(comment);
    }
  }

  void _handleAuctionUpdated(dynamic data) {
    final payload = _parseAuctionUpdatedPayload(data);
    if (payload == null) return;

    final lastComment = payload.lastComment;
    if (lastComment != null && !_newCommentController.isClosed) {
      _newCommentController.add(lastComment);
    }

    if (!_auctionUpdatedController.isClosed) {
      _auctionUpdatedController.add(payload);
    }
  }

  /// Parses `newComment` — flat comment JSON on the post room.
  CommentModel? _parseCommentPayload(dynamic data) {
    final map = _unwrapPayload(data);
    if (map == null) return null;

    final fallbackPostId = map['postId']?.toString() ?? _joinedPostId;

    for (final key in ['newComment', 'comment', 'data']) {
      final raw = map[key];
      if (raw is! Map) continue;
      final comment = _tryParseComment(
        Map<String, dynamic>.from(raw),
        fallbackPostId: fallbackPostId,
      );
      if (comment != null) return comment;
    }

    return _tryParseComment(map, fallbackPostId: fallbackPostId);
  }

  AuctionUpdatedPayload? _parseAuctionUpdatedPayload(dynamic data) {
    final map = _unwrapPayload(data);
    if (map == null) return null;

    final auctionId = map['auctionId']?.toString();
    final postId = map['postId']?.toString();
    final currentTotalCoins = _readInt(map['currentTotalCoins']);
    final targetPriceCoins = _readInt(map['targetPriceCoins']);
    final startingPriceCoins = _readInt(map['startingPriceCoins']);
    final status = map['status']?.toString();
    final winnerId = map['winnerId']?.toString();

    final fallbackPostId = postId ?? _joinedPostId;

    CommentModel? lastComment;
    final lastCommentRaw = map['lastComment'];
    if (lastCommentRaw is Map) {
      lastComment = _tryParseComment(
        Map<String, dynamic>.from(lastCommentRaw),
        fallbackPostId: fallbackPostId,
      );
    }

    Map<String, dynamic>? lastGift;
    final lastGiftRaw = map['lastGift'];
    if (lastGiftRaw is Map) {
      lastGift = Map<String, dynamic>.from(lastGiftRaw);
    }

    if (auctionId == null &&
        postId == null &&
        currentTotalCoins == null &&
        targetPriceCoins == null &&
        lastComment == null &&
        lastGift == null &&
        status == null) {
      return null;
    }

    return AuctionUpdatedPayload(
      auctionId: auctionId,
      postId: postId ?? lastComment?.postId,
      currentTotalCoins: currentTotalCoins,
      targetPriceCoins: targetPriceCoins,
      startingPriceCoins: startingPriceCoins,
      status: status,
      winnerId: winnerId,
      lastComment: lastComment,
      lastGift: lastGift,
    );
  }

  Map<String, dynamic>? _unwrapPayload(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return _unwrapPayload(data.first);
    }
    if (data is! Map) return null;
    var map = Map<String, dynamic>.from(data);

    final nested = map['data'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      final isEnvelope = map.containsKey('event') ||
          (map.containsKey('data') &&
              !map.containsKey('auctionId') &&
              !map.containsKey('lastComment') &&
              !map.containsKey('lastGift') &&
              !map.containsKey('content') &&
              !map.containsKey('id'));
      if (isEnvelope) {
        map = nestedMap;
      }
    }

    return map;
  }

  CommentModel? _tryParseComment(
    Map<String, dynamic> json, {
    String? fallbackPostId,
  }) {
    if (!json.containsKey('id') &&
        !json.containsKey('content') &&
        json['isGift'] != true &&
        json['gift'] == null) {
      return null;
    }
    try {
      final merged = Map<String, dynamic>.from(json);
      final postId = merged['postId']?.toString() ?? '';
      if (postId.isEmpty &&
          fallbackPostId != null &&
          fallbackPostId.isNotEmpty) {
        merged['postId'] = fallbackPostId;
      }

      // Some payloads flag gifts without explicit isGift.
      if (merged['gift'] is Map && merged['isGift'] != true) {
        merged['isGift'] = true;
      }

      final comment = CommentModel.fromJson(merged);
      if (comment.id.isEmpty) {
        String? fallbackId = merged['giftId']?.toString();
        final nestedGift = merged['gift'];
        if ((fallbackId == null || fallbackId.isEmpty) && nestedGift is Map) {
          fallbackId = nestedGift['id']?.toString();
        }
        if (fallbackId == null || fallbackId.isEmpty) return null;
        return CommentModel.fromJson({
          ...merged,
          'id': 'gift-$fallbackId-${merged['userId'] ?? 'anon'}',
        });
      }
      return comment;
    } catch (_) {
      return null;
    }
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  void disconnect() {
    _joinedAuctionId = null;
    _joinedPostId = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  void dispose() {
    disconnect();
    _auctionUpdatedController.close();
    _newCommentController.close();
    _connectionController.close();
  }
}
