import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/socket_event.dart';
import '../../domain/repositories/gift_repository.dart';
import '../services/fake_socket_service.dart'
    show MockGiftCatalog, SocketService;

/// Real [GiftRepository] backed by the backend:
/// - `GET  /auth/me`           → coin balance (`wallet.balanceCoins`)
/// - `POST /gifts/send`        → send a gift
/// - `GET  /lives/:id/leaderboard/gifters` → top gifters
/// - Socket `liveGift` events  → incoming gifts stream
///
/// Gift catalog has no public endpoint in mobile-api.md — reuses the local
/// mock catalog for the picker UI.
class RealGiftRepository implements GiftRepository {
  RealGiftRepository({
    required LiveApiClient apiClient,
    required SocketService socket,
  }) : _api = apiClient,
       _socket = socket;

  final LiveApiClient _api;
  final SocketService _socket;

  final Map<String, StreamController<GiftSentEntity>> _incoming = {};

  @override
  Future<Either<Failure, List<GiftEntity>>> getAllGifts() async {
    return Right(List.unmodifiable(MockGiftCatalog.gifts));
  }

  @override
  Future<Either<Failure, List<GiftEntity>>> getGiftsByRarity(
    GiftRarity rarity,
  ) async {
    final gifts = MockGiftCatalog.gifts
        .where((g) => g.rarity == rarity)
        .toList();
    return Right(gifts);
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
    if (receiverId == null || receiverId.trim().isEmpty) {
      return const Left(ValidationFailure('A verified recipient is required.'));
    }
    // Production sending is owned by lib/app/gifts and LiveGiftSheet. This
    // legacy picker must not send local catalog IDs or infer transaction IDs.
    return const Left(ServerFailure('Use the LIVE gift sheet to send gifts.'));
  }

  @override
  Future<Either<Failure, List<GiftSentEntity>>> getGiftHistory({
    int page = 1,
    int limit = 20,
  }) async {
    // No dedicated history endpoint for the viewer — return empty.
    return const Right([]);
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
              username: (() {
                final full = userMap?['fullName']?.toString().trim();
                if (full != null && full.isNotEmpty) return full;
                return userMap?['username']?.toString() ?? 'User';
              })(),
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
    // No purchase endpoint in the current backend scope — no-op.
    return const Left(ServerFailure('Open the wallet to purchase coins.'));
  }

  @override
  Stream<Either<Failure, GiftSentEntity>> watchIncomingGifts(String liveId) {
    // Ownership follows the returned subscription: cancellation detaches from
    // the shared socket automatically, including repeated room entry.
    return _socket.events
        .where((event) => event is LiveGiftEvent && event.liveId == liveId)
        .map(
          (event) =>
              Right<Failure, GiftSentEntity>((event as LiveGiftEvent).gift),
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
