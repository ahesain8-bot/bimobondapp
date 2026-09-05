import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart' as catalog;
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/socket_event.dart';
import '../../domain/repositories/gift_repository.dart';
import '../services/fake_socket_service.dart' show SocketService;

/// Real [GiftRepository] backed by the backend:
/// - `GET  /auth/me`           → coin balance (`wallet.balanceCoins`)
/// - `POST /gifts/send`        → send a gift
/// - `GET  /lives/:id/leaderboard/gifters` → top gifters
/// - Socket `liveGift` events  → incoming gifts stream
///
/// Gift catalog is loaded through the app's existing GiftsRepository, which
/// owns the catalog API. Live-specific sending remains on `/gifts/send`.
class RealGiftRepository implements GiftRepository {
  RealGiftRepository({
    required LiveApiClient apiClient,
    required SocketService socket,
    required GiftsRepository catalogRepository,
  }) : _api = apiClient,
       _socket = socket,
       _catalogRepository = catalogRepository;

  final LiveApiClient _api;
  final SocketService _socket;
  final GiftsRepository _catalogRepository;

  final Map<String, StreamController<GiftSentEntity>> _incoming = {};

  @override
  Future<Either<Failure, List<GiftEntity>>> getAllGifts() async {
    try {
      return Right(await _loadCatalog());
    } catch (e) {
      return Left(ServerFailure('Failed to load gift catalog: $e'));
    }
  }

  @override
  Future<Either<Failure, List<GiftEntity>>> getGiftsByRarity(
    GiftRarity rarity,
  ) async {
    try {
      // Rarity is not part of the documented catalog response. Do not invent
      // a client-side catalog partition.
      return Right(await _loadCatalog());
    } catch (e) {
      return Left(ServerFailure('Failed to load gift catalog: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getCoinBalance() async {
    try {
      final payload = await _api.get(ApiEndpoints.authMe);
      final wallet = payload['wallet'];
      final balance = wallet is Map<String, dynamic>
          ? wallet['balanceCoins']
          : payload['balanceCoins'];
      final value = _asInt(balance);
      if (value == null) {
        return const Left(ServerFailure('Coin balance missing from /auth/me'));
      }
      return Right(value);
    } catch (e) {
      return Left(ServerFailure('Failed to load coin balance: $e'));
    }
  }

  @override
  Future<Either<Failure, GiftSentEntity>> sendGift({
    required String liveId,
    required String giftId,
    int quantity = 1,
    String? receiverId,
  }) async {
    try {
      final catalogGifts = await _loadCatalog();
      GiftEntity? gift;
      for (final item in catalogGifts) {
        if (item.id == giftId) {
          gift = item;
          break;
        }
      }
      if (gift == null) {
        return const Left(NotFoundFailure('Gift not found'));
      }

      final payload = await _api.post(
        ApiEndpoints.giftsSend,
        body: {
          'giftId': giftId,
          'receiverId': receiverId ?? liveId,
          'liveId': liveId,
          if (quantity > 1) 'quantity': quantity,
        },
      );

      final total = gift.coinCost * quantity;
      final sent = GiftSentEntity(
        id:
            payload['id']?.toString() ??
            'sent_${DateTime.now().microsecondsSinceEpoch}',
        giftId: giftId,
        liveId: liveId,
        senderId: payload['senderId']?.toString() ?? '',
        senderName: payload['senderName']?.toString() ?? 'You',
        senderAvatar: payload['senderAvatar']?.toString(),
        quantity: quantity,
        totalCost: _asInt(payload['totalCost']) ?? total,
        sentAt: DateTime.now(),
        giftDetails: gift,
        senderGifterLevel: _asInt(
          payload['sender'] is Map
              ? Map<String, dynamic>.from(
                  payload['sender'] as Map,
                )['gifterLevel']
              : payload['gifterLevel'],
        ),
      );

      _incoming[liveId]?.add(sent);
      return Right(sent);
    } catch (e) {
      return Left(ServerFailure('Failed to send gift: $e'));
    }
  }

  @override
  Future<Either<Failure, List<GiftSentEntity>>> getGiftHistory({
    int page = 1,
    int limit = 20,
  }) async {
    // No dedicated history endpoint for the viewer — return empty.
    return const Left(
      ServerFailure('Gift history endpoint is not documented by the API.'),
    );
  }

  @override
  Future<Either<Failure, List<GiftLeaderboardEntry>>> getTopGifters(
    String liveId, {
    int limit = 10,
  }) async {
    try {
      final payload = await _api.get(
        ApiEndpoints.liveGiftersLeaderboard(liveId),
        query: {'window': 'session', 'limit': '$limit'},
      );

      final data = payload['data'];
      final entries = <GiftLeaderboardEntry>[];
      if (data is List) {
        var rank = 1;
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          final user = item['user'];
          final userMap = user is Map<String, dynamic>
              ? user
              : (user is Map ? Map<String, dynamic>.from(user) : null);
          entries.add(
            GiftLeaderboardEntry(
              userId:
                  userMap?['id']?.toString() ??
                  item['userId']?.toString() ??
                  '',
              username:
                  userMap?['username']?.toString() ??
                  userMap?['fullName']?.toString() ??
                  'User',
              avatarUrl: userMap?['avatarUrl']?.toString(),
              totalCoins: _asInt(item['coins'] ?? item['totalCoins']) ?? 0,
              rank: _asInt(item['rank']) ?? rank,
            ),
          );
          rank++;
        }
      }
      return Right(entries);
    } catch (e) {
      return Left(ServerFailure('Failed to load top gifters: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> purchaseCoins(int amount) async {
    // No purchase endpoint is defined in the current backend scope.
    return const Left(
      ServerFailure('Coin purchase endpoint is not documented by the API.'),
    );
  }

  @override
  Stream<Either<Failure, GiftSentEntity>> watchIncomingGifts(String liveId) {
    _incoming.putIfAbsent(
      liveId,
      () => StreamController<GiftSentEntity>.broadcast(),
    );

    final controller = _incoming[liveId]!;
    _socket.events.listen((event) {
      if (event.liveId != liveId) return;
      if (event is LiveGiftEvent) {
        controller.add(event.gift);
      }
    });

    return controller.stream.map(Right.new);
  }

  Future<List<GiftEntity>> _loadCatalog() async {
    final result = await _catalogRepository.getGifts();
    return result.fold(
      (failure) => throw StateError(failure.message),
      (gifts) => gifts.map(_mapCatalogGift).toList(growable: false),
    );
  }

  GiftEntity _mapCatalogGift(catalog.GiftEntity gift) {
    return GiftEntity(
      id: gift.id,
      name: gift.name,
      iconUrl: gift.displayImageUrl ?? gift.icon,
      animationUrl: gift.animationUrl,
      coinCost: gift.priceCoins,
      hasAnimation: gift.animationUrl != null,
      metadata: {
        if (gift.thumbnailUrl != null) 'thumbnailUrl': gift.thumbnailUrl,
        if (gift.audioUrl != null) 'audioUrl': gift.audioUrl,
        'type': gift.type.name,
        'size': gift.size.name,
      },
    );
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  void dispose() {
    for (final c in _incoming.values) {
      c.close();
    }
  }
}
