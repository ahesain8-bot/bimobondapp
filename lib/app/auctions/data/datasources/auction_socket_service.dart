import 'dart:async';

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

    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;

    _socket?.dispose();
    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    final connected = Completer<void>();

    _socket!
      ..onConnect((_) {
        _connectionController.add(true);
        _rejoinRooms();
        if (!connected.isCompleted) connected.complete();
      })
      ..onDisconnect((_) => _connectionController.add(false))
      ..onConnectError((_) {
        if (!connected.isCompleted) connected.complete();
      })
      ..on(AuctionSocketEvent.auctionUpdated, _handleAuctionUpdated)
      ..on(AuctionSocketEvent.newComment, _handleNewComment);

    _socket!.connect();

    try {
      await connected.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      // Room joins are retried on reconnect via _rejoinRooms().
    }
  }

  void joinAuction(String auctionId) {
    if (auctionId.isEmpty) return;
    _joinedAuctionId = auctionId;
    _socket?.emit(AuctionSocketEvent.joinAuction, {'auctionId': auctionId});
  }

  void leaveAuction(String auctionId) {
    if (auctionId.isEmpty) return;
    if (_joinedAuctionId == auctionId) {
      _joinedAuctionId = null;
    }
    _socket?.emit(AuctionSocketEvent.leaveAuction, {'auctionId': auctionId});
  }

  void joinPost(String postId) {
    if (postId.isEmpty) return;
    _joinedPostId = postId;
    _socket?.emit(AuctionSocketEvent.joinPost, {'postId': postId});
  }

  void leavePost(String postId) {
    if (postId.isEmpty) return;
    if (_joinedPostId == postId) {
      _joinedPostId = null;
    }
    _socket?.emit(AuctionSocketEvent.leavePost, {'postId': postId});
  }

  void _rejoinRooms() {
    final auctionId = _joinedAuctionId;
    if (auctionId != null && auctionId.isNotEmpty) {
      _socket?.emit(AuctionSocketEvent.joinAuction, {'auctionId': auctionId});
    }
    final postId = _joinedPostId;
    if (postId != null && postId.isNotEmpty) {
      _socket?.emit(AuctionSocketEvent.joinPost, {'postId': postId});
    }
  }

  void _handleNewComment(dynamic data) {
    final comment = _parseCommentPayload(data);
    if (comment == null) return;
    _newCommentController.add(comment);
  }

  void _handleAuctionUpdated(dynamic data) {
    final payload = _parseAuctionUpdatedPayload(data);
    if (payload == null) return;

    final lastComment = payload.lastComment;
    if (lastComment != null) {
      _newCommentController.add(lastComment);
    }

    _auctionUpdatedController.add(payload);
  }

  /// Parses `newComment` — flat comment JSON on the post room.
  CommentModel? _parseCommentPayload(dynamic data) {
    final map = _unwrapPayload(data);
    if (map == null) return null;

    final fallbackPostId =
        map['postId']?.toString() ?? _joinedPostId;

    for (final key in ['newComment', 'comment']) {
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

    final fallbackPostId =
        postId ?? map['postId']?.toString() ?? _joinedPostId;

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
              !map.containsKey('content'));
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
    if (!json.containsKey('id') && !json.containsKey('content')) {
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

      final comment = CommentModel.fromJson(merged);
      if (comment.id.isEmpty) return null;
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
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _auctionUpdatedController.close();
    _newCommentController.close();
    _connectionController.close();
  }
}
