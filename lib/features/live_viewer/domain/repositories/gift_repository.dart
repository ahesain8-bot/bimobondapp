import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/gift_entity.dart';

abstract class GiftRepository {
  /// Get all available gifts
  Future<Either<Failure, List<GiftEntity>>> getAllGifts();

  /// Get gifts by rarity
  Future<Either<Failure, List<GiftEntity>>> getGiftsByRarity(GiftRarity rarity);

  /// Get user's coin balance
  Future<Either<Failure, int>> getCoinBalance();

  /// Send a gift to a live. [receiverId] is the host user id — the backend
  /// overrides it to the live host when omitted.
  Future<Either<Failure, GiftSentEntity>> sendGift({
    required String liveId,
    required String giftId,
    int quantity = 1,
    String? receiverId,
  });

  /// Get gift history
  Future<Either<Failure, List<GiftSentEntity>>> getGiftHistory({
    int page = 1,
    int limit = 20,
  });

  /// Get top gifters for a live
  Future<Either<Failure, List<GiftLeaderboardEntry>>> getTopGifters(
    String liveId, {
    int limit = 10,
  });

  /// Purchase coins
  Future<Either<Failure, int>> purchaseCoins(int amount);

  /// Watch for incoming gifts (for streamers)
  Stream<Either<Failure, GiftSentEntity>> watchIncomingGifts(String liveId);
}

class GiftLeaderboardEntry extends Equatable {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int totalCoins;
  final int rank;

  const GiftLeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.totalCoins,
    required this.rank,
  });

  @override
  List<Object?> get props => [userId, username, avatarUrl, totalCoins, rank];
}
