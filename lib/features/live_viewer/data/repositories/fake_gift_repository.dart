import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/repositories/gift_repository.dart';
import '../services/fake_socket_service.dart';

class FakeGiftRepository implements GiftRepository {
  final SocketService _socket;
  int _coinBalance = 1250;
  final List<GiftSentEntity> _history = [];
  final Map<String, StreamController<GiftSentEntity>> _incoming = {};

  FakeGiftRepository(this._socket);

  @override
  Future<Either<Failure, List<GiftEntity>>> getAllGifts() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Right(List.unmodifiable(MockGiftCatalog.gifts));
  }

  @override
  Future<Either<Failure, List<GiftEntity>>> getGiftsByRarity(
    GiftRarity rarity,
  ) async {
    final gifts =
        MockGiftCatalog.gifts.where((g) => g.rarity == rarity).toList();
    return Right(gifts);
  }

  @override
  Future<Either<Failure, int>> getCoinBalance() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Right(_coinBalance);
  }

  @override
  Future<Either<Failure, GiftSentEntity>> sendGift({
    required String liveId,
    required String giftId,
    int quantity = 1,
    String? receiverId,
  }) async {
    // POST /gifts/send
    await Future.delayed(const Duration(milliseconds: 350));

    final gift = MockGiftCatalog.byId(giftId);
    if (gift == null) {
      return const Left(NotFoundFailure('Gift not found'));
    }

    final total = gift.coinCost * quantity;
    if (_coinBalance < total) {
      return const Left(ValidationFailure('Not enough coins'));
    }

    _coinBalance -= total;

    final sent = GiftSentEntity(
      id: 'sent_${DateTime.now().microsecondsSinceEpoch}',
      giftId: giftId,
      liveId: liveId,
      senderId: 'current_user',
      senderName: 'You',
      senderAvatar: 'https://i.pravatar.cc/150?u=me',
      quantity: quantity,
      totalCost: total,
      sentAt: DateTime.now(),
      giftDetails: gift,
    );

    _history.insert(0, sent);
    await _socket.emitGift(sent);
    _incoming[liveId]?.add(sent);

    return Right(sent);
  }

  @override
  Future<Either<Failure, List<GiftSentEntity>>> getGiftHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final start = (page - 1) * limit;
    if (start >= _history.length) return const Right([]);
    final end = (start + limit).clamp(0, _history.length);
    return Right(_history.sublist(start, end));
  }

  @override
  Future<Either<Failure, List<GiftLeaderboardEntry>>> getTopGifters(
    String liveId, {
    int limit = 10,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Right([
      const GiftLeaderboardEntry(
        userId: 'u1',
        username: 'BigSpender',
        avatarUrl: 'https://i.pravatar.cc/150?u=big',
        totalCoins: 12500,
        rank: 1,
      ),
      const GiftLeaderboardEntry(
        userId: 'u2',
        username: 'GiftQueen',
        avatarUrl: 'https://i.pravatar.cc/150?u=queen',
        totalCoins: 8200,
        rank: 2,
      ),
      const GiftLeaderboardEntry(
        userId: 'u3',
        username: 'You',
        avatarUrl: 'https://i.pravatar.cc/150?u=me',
        totalCoins: 450,
        rank: 3,
      ),
    ]);
  }

  @override
  Future<Either<Failure, int>> purchaseCoins(int amount) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _coinBalance += amount;
    return Right(_coinBalance);
  }

  @override
  Stream<Either<Failure, GiftSentEntity>> watchIncomingGifts(String liveId) {
    _incoming.putIfAbsent(
      liveId,
      () => StreamController<GiftSentEntity>.broadcast(),
    );
    return _incoming[liveId]!.stream.map(Right.new);
  }
}
