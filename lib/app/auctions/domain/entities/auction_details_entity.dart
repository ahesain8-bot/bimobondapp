import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_entity.dart';
import 'package:equatable/equatable.dart';

class AuctionUserEntity extends Equatable {
  const AuctionUserEntity({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl];
}

class AuctionGiftSummaryEntity extends Equatable {
  const AuctionGiftSummaryEntity({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    required this.priceCoins,
  });

  final String id;
  final String name;
  final String? thumbnailUrl;
  final int priceCoins;

  @override
  List<Object?> get props => [id, name, thumbnailUrl, priceCoins];
}

class AuctionGiftTransactionEntity extends Equatable {
  const AuctionGiftTransactionEntity({
    required this.id,
    required this.priceCoins,
    required this.contributionCoins,
    required this.createdAt,
    required this.sender,
    required this.gift,
  });

  final String id;
  final int priceCoins;
  final int contributionCoins;
  final DateTime createdAt;
  final AuctionUserEntity sender;
  final AuctionGiftSummaryEntity gift;

  @override
  List<Object?> get props =>
      [id, priceCoins, contributionCoins, createdAt, sender, gift];
}

class AuctionDetailsEntity extends Equatable {
  const AuctionDetailsEntity({
    required this.id,
    required this.itemName,
    required this.targetPrice,
    required this.targetPriceCoins,
    required this.currentTotalCoins,
    required this.currencyCode,
    required this.status,
    required this.host,
    this.winner,
    required this.giftTransactions,
    this.pricing,
  });

  final String id;
  final String itemName;
  final double targetPrice;
  final int targetPriceCoins;
  final int currentTotalCoins;
  final String currencyCode;
  final String status;
  final AuctionUserEntity host;
  final AuctionUserEntity? winner;
  final List<AuctionGiftTransactionEntity> giftTransactions;
  final AuctionPricingEntity? pricing;

  double get progressPercent {
    if (pricing != null && pricing!.progressPercent > 0) {
      return pricing!.progressPercent.clamp(0, 100);
    }
    if (targetPriceCoins <= 0) return 0;
    return (currentTotalCoins / targetPriceCoins * 100).clamp(0, 100);
  }

  @override
  List<Object?> get props => [
        id,
        itemName,
        targetPrice,
        targetPriceCoins,
        currentTotalCoins,
        currencyCode,
        status,
        host,
        winner,
        giftTransactions,
        pricing,
      ];
}
