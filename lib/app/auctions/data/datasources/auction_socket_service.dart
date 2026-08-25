import 'dart:async';
import 'dart:developer' as developer;

import 'package:bimobondapp/app/gifts/data/datasources/gift_catalog_hydrator.dart';
import 'package:bimobondapp/app/posts/data/models/comment_model.dart';
import 'package:bimobondapp/core/network/api_endpoints.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket.io events for auction / live / gift realtime.
class AuctionSocketEvent {
  AuctionSocketEvent._();

  static const joinAuction = 'joinAuction';
  static const leaveAuction = 'leaveAuction';
  static const joinPost = 'joinPost';
  static const leavePost = 'leavePost';
  static const joinLive = 'joinLive';
  static const leaveLive = 'leaveLive';
  static const joinUser = 'joinUser';

  static const sendGift = 'sendGift';

  static const auctionUpdated = 'auctionUpdated';
  static const newComment = 'newComment';
  static const liveComment = 'liveComment';

  /// Prefer this single live animation event (do not also listen to aliases).
  static const giftCombo = 'gift_combo';

  /// Server emits camelCase `auctionGiftCombo` (see EventsGateway logs).
  static const auctionGiftCombo = 'auctionGiftCombo';
  static const liveAuction = 'liveAuction';

  /// Live shopping bag updates (pin/add/remove/reorder).
  static const liveProduct = 'liveProduct';
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
    this.combo,
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
  final int? combo;

  bool get hasGiftActivity => lastGift != null && lastGift!.isNotEmpty;
}

class GiftComboPayload {
  const GiftComboPayload({
    required this.giftId,
    required this.senderId,
    required this.receiverId,
    required this.quantity,
    required this.combo,
    this.liveId = '',
    this.auctionId,
    this.transactionId = '',
    this.gift,
    this.sender,
    this.receiver,
    this.giftName,
    this.senderName,
    this.senderAvatarUrl,
    this.coins,
    this.timestamp,
  });

  final String liveId;
  final String? auctionId;
  final String transactionId;
  final String giftId;
  final String senderId;
  final String receiverId;
  final int quantity;
  final int combo;
  final Map<String, dynamic>? gift;
  final Map<String, dynamic>? sender;
  final Map<String, dynamic>? receiver;

  /// Flat field from `auctionGiftCombo` when nested `gift` is omitted.
  final String? giftName;
  final String? senderName;
  final String? senderAvatarUrl;
  final int? coins;
  final String? timestamp;

  /// Overlay key: live → `senderId_giftId`; auction → `auction_{id}_{sender}_{gift}`.
  String get overlayKey {
    final auction = auctionId?.trim();
    if (auction != null && auction.isNotEmpty) {
      return 'auction_${auction}_${senderId}_$giftId';
    }
    return '${senderId}_$giftId';
  }

  static GiftComboPayload? fromMap(Map<String, dynamic> map) {
    final senderRaw = map['sender'] ?? map['user'];
    final senderObj = senderRaw is Map
        ? Map<String, dynamic>.from(senderRaw)
        : null;
    final receiverObj = map['receiver'] is Map
        ? Map<String, dynamic>.from(map['receiver'] as Map)
        : null;

    final giftId = (map['giftId'] ?? map['gift']?['id'])?.toString();
    final senderId = (map['senderId'] ?? map['sender_id'] ?? senderObj?['id'])
        ?.toString();
    if (giftId == null || giftId.isEmpty) return null;

    final rawCombo = map['combo'];
    final combo = rawCombo is int ? rawCombo : (int.tryParse('$rawCombo') ?? 1);

    final rawQty = map['quantity'] ?? map['qty'];
    final quantity = rawQty is int ? rawQty : (int.tryParse('$rawQty') ?? 1);

    final giftObj = map['gift'] is Map
        ? Map<String, dynamic>.from(map['gift'] as Map)
        : null;

    final giftName = (map['giftName'] ?? map['gift_name'] ?? giftObj?['name'])
        ?.toString();
    final senderName =
        (map['senderName'] ?? senderObj?['fullName'] ?? senderObj?['username'])
            ?.toString();
    final senderAvatarUrl = (map['senderAvatarUrl'] ?? senderObj?['avatarUrl'])
        ?.toString();
    final rawCoins = map['coins'];
    final coins = rawCoins is int ? rawCoins : int.tryParse('$rawCoins');

    // Server auctionGiftCombo is often flat (giftId/giftName/coins) with no
    // nested gift. Preserve any presentation fields that the server includes
    // at the top level so the shared renderer can consume the normalized gift.
    final resolvedGift = <String, dynamic>{'id': giftId};
    if (giftName != null && giftName.isNotEmpty) {
      resolvedGift['name'] = giftName;
    }
    for (final entry in giftPayloadFlatFields.entries) {
      final value = map[entry.key];
      if (value != null && value.toString().trim().isNotEmpty) {
        resolvedGift[entry.value] = value;
      }
    }
    if (giftObj != null) {
      for (final entry in giftObj.entries) {
        if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
          resolvedGift[entry.key] = entry.value;
        }
      }
    }

    return GiftComboPayload(
      liveId: (map['liveId'] ?? map['live_id'])?.toString() ?? '',
      auctionId: map['auctionId']?.toString(),
      transactionId:
          (map['transactionId'] ?? map['tx'] ?? map['id'])?.toString() ?? '',
      giftId: giftId,
      senderId: senderId ?? '',
      receiverId:
          (map['receiverId'] ?? map['receiver_id'] ?? receiverObj?['id'])
              ?.toString() ??
          '',
      quantity: quantity > 0 ? quantity : 1,
      combo: combo > 0 ? combo : 1,
      gift: resolvedGift,
      sender: senderObj,
      receiver: receiverObj,
      giftName: giftName,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      coins: coins,
      timestamp: map['timestamp']?.toString(),
    );
  }
}

/// Result of socket `sendGift` ack (`giftSent` or `error`).
class GiftSocketSendResult {
  const GiftSocketSendResult._({this.data, this.errorMessage});

  final Map<String, dynamic>? data;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null && data != null;

  int? get combo {
    final raw = data?['combo'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  int? get inventoryQuantity {
    final inv = data?['senderInventory'];
    if (inv is! Map) return null;
    final raw = inv['quantity'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  String? get inventoryGiftId {
    final inv = data?['senderInventory'];
    if (inv is! Map) return null;
    return inv['giftId']?.toString();
  }

  factory GiftSocketSendResult.success(Map<String, dynamic> data) =>
      GiftSocketSendResult._(data: data);

  factory GiftSocketSendResult.error(String message) =>
      GiftSocketSendResult._(errorMessage: message);
}

class AuctionSocketService {
  AuctionSocketService({GiftCatalogLoader? giftCatalogLoader})
    : _giftCatalog = giftCatalogLoader == null
          ? null
          : GiftCatalogHydrator(giftCatalogLoader);

  /// Fills in the media/size the server omits from flat combo payloads. Shared
  /// by every listener, so the host and the viewer render the same gift.
  final GiftCatalogHydrator? _giftCatalog;

  io.Socket? _socket;
  String? _joinedAuctionId;
  String? _joinedPostId;
  String? _joinedLiveId;
  bool _connecting = false;

  final _auctionUpdatedController =
      StreamController<AuctionUpdatedPayload>.broadcast();
  final _newCommentController = StreamController<CommentModel>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _giftComboController = StreamController<GiftComboPayload>.broadcast();
  final _liveAuctionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _liveProductController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<AuctionUpdatedPayload> get onAuctionUpdated =>
      _auctionUpdatedController.stream;
  Stream<CommentModel> get onNewComment => _newCommentController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<GiftComboPayload> get onGiftCombo => _giftComboController.stream;
  Stream<Map<String, dynamic>> get onLiveAuction =>
      _liveAuctionController.stream;
  Stream<Map<String, dynamic>> get onLiveProduct =>
      _liveProductController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket?.connected == true) {
      _rejoinRooms();
      return;
    }
    if (_connecting) {
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
        // Use the same configurable host as the live room. Otherwise a build
        // with API_BASE_URL set joins live_<id> on one server but sends the
        // gift through the hard-coded default server.
        ApiEndpoints.baseUrl,
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
        ..on(AuctionSocketEvent.newComment, _handleNewComment)
        ..on(AuctionSocketEvent.liveComment, _handleNewComment)
        // Listen to ONE live animation event only (avoid double play).
        ..on(AuctionSocketEvent.giftCombo, _handleGiftCombo)
        ..on(AuctionSocketEvent.auctionGiftCombo, _handleGiftCombo)
        ..on(AuctionSocketEvent.liveAuction, _handleLiveAuction)
        ..on(AuctionSocketEvent.liveProduct, _handleLiveProduct);

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

  void joinLive(String liveId) {
    if (liveId.isEmpty) return;
    _joinedLiveId = liveId;
    _emitJoinLive(liveId);
  }

  void leaveLive(String liveId) {
    if (liveId.isEmpty) return;
    if (_joinedLiveId == liveId) {
      _joinedLiveId = null;
    }
    if (_socket?.connected == true) {
      _socket?.emit(AuctionSocketEvent.leaveLive, {'liveId': liveId});
    }
  }

  /// Stores target rooms and connects (or rejoins if already online).
  Future<void> ensureJoined({
    String? postId,
    String? auctionId,
    String? liveId,
  }) async {
    if (postId != null && postId.isNotEmpty) {
      _joinedPostId = postId;
    }
    if (auctionId != null && auctionId.isNotEmpty) {
      _joinedAuctionId = auctionId;
    }
    if (liveId != null && liveId.isNotEmpty) {
      _joinedLiveId = liveId;
    }
    await connect();
    _rejoinRooms();
  }

  /// Socket `sendGift` with ack. Prefer for live/auction rapid tap.
  /// Returns null when socket is offline (caller should use HTTP fallback).
  Future<GiftSocketSendResult?> sendGift({
    required String giftId,
    String? liveId,
    String? auctionId,
    int quantity = 1,
    String? message,
    String? receiverId,
  }) async {
    final socket = _socket;
    if (socket == null || !socket.connected) return null;

    final payload = <String, dynamic>{
      'giftId': giftId,
      'quantity': quantity < 1 ? 1 : quantity,
      if (liveId != null && liveId.isNotEmpty) 'liveId': liveId,
      if (auctionId != null && auctionId.isNotEmpty) 'auctionId': auctionId,
      if (message != null && message.isNotEmpty) 'message': message,
      if (receiverId != null && receiverId.isNotEmpty) 'receiverId': receiverId,
    };

    try {
      final raw = await socket
          .emitWithAckAsync(AuctionSocketEvent.sendGift, payload)
          .timeout(const Duration(seconds: 12));
      return _parseSendGiftAck(raw);
    } catch (e) {
      developer.log('AuctionSocket sendGift failed: $e', name: 'AuctionSocket');
      return GiftSocketSendResult.error(e.toString());
    }
  }

  GiftSocketSendResult _parseSendGiftAck(dynamic raw) {
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
      map = Map<String, dynamic>.from(raw.first as Map);
    }
    if (map == null) {
      return GiftSocketSendResult.error('Invalid gift send response');
    }

    final event = map['event']?.toString();
    final dataRaw = map['data'];
    final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : null;

    if (event == 'error') {
      final message = (data?['message'] ?? map['message'] ?? 'Send failed')
          .toString();
      return GiftSocketSendResult.error(message);
    }

    if (event == 'giftSent' && data != null) {
      return GiftSocketSendResult.success(data);
    }

    if (data != null &&
        (data.containsKey('combo') || data.containsKey('giftId'))) {
      return GiftSocketSendResult.success(data);
    }

    if (map.containsKey('combo') || map.containsKey('giftId')) {
      return GiftSocketSendResult.success(map);
    }

    final message = (data?['message'] ?? map['message'] ?? 'Send failed')
        .toString();
    return GiftSocketSendResult.error(message);
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

  void _emitJoinLive(String liveId) {
    if (_socket?.connected != true) return;
    _socket!.emit(AuctionSocketEvent.joinLive, {'liveId': liveId});
    developer.log('AuctionSocket joinLive $liveId', name: 'AuctionSocket');
  }

  void _emitJoinUser() {
    if (_socket?.connected != true) return;
    _socket!.emit(AuctionSocketEvent.joinUser, {});
    developer.log('AuctionSocket joinUser', name: 'AuctionSocket');
  }

  void _rejoinRooms() {
    _emitJoinUser();
    final postId = _joinedPostId;
    if (postId != null && postId.isNotEmpty) {
      _emitJoinPost(postId);
    }
    final liveId = _joinedLiveId;
    if (liveId != null && liveId.isNotEmpty) {
      _emitJoinLive(liveId);
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

  void _handleGiftCombo(dynamic data) {
    final map = _unwrapPayload(data);
    if (map == null) return;

    unawaited(
      _emitGiftCombo(map).catchError((Object error) {
        developer.log(
          'gift combo dispatch failed: $error',
          name: 'AuctionSocket',
        );
      }),
    );
  }

  Future<void> _emitGiftCombo(Map<String, dynamic> map) async {
    final catalog = _giftCatalog;
    final giftId = (map['giftId'] ?? map['gift']?['id'])?.toString();
    if (catalog != null && giftId != null && giftId.isNotEmpty) {
      await catalog.hydrate(map, giftId);
    }

    final payload = GiftComboPayload.fromMap(map);
    if (payload != null && !_giftComboController.isClosed) {
      _giftComboController.add(payload);
    }
  }

  void _handleLiveAuction(dynamic data) {
    final map = _unwrapPayload(data);
    if (map == null || _liveAuctionController.isClosed) return;
    _liveAuctionController.add(map);
  }

  void _handleLiveProduct(dynamic data) {
    final map = _unwrapPayload(data);
    if (map == null || _liveProductController.isClosed) return;
    _liveProductController.add(map);
  }

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
    final combo = _readInt(map['combo']);

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
      combo: combo,
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
      final isEnvelope =
          map.containsKey('event') ||
          (map.containsKey('data') &&
              !map.containsKey('auctionId') &&
              !map.containsKey('lastComment') &&
              !map.containsKey('lastGift') &&
              !map.containsKey('content') &&
              !map.containsKey('id') &&
              !map.containsKey('giftId') &&
              !map.containsKey('combo'));
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
    _joinedLiveId = null;
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
    _giftComboController.close();
    _liveAuctionController.close();
    _liveProductController.close();
  }
}
