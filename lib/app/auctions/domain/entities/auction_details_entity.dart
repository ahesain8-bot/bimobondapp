import 'package:equatable/equatable.dart';

class AuctionUserEntity extends Equatable {
  const AuctionUserEntity({
    required this.id,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String? username;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, username, avatarUrl];
}

class AuctionGiftSummaryEntity extends Equatable {
  const AuctionGiftSummaryEntity({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    required this.priceUsd,
  });

  final String id;
  final String name;
  final String? thumbnailUrl;
  final double priceUsd;

  @override
  List<Object?> get props => [id, name, thumbnailUrl, priceUsd];
}

class AuctionGiftTransactionEntity extends Equatable {
  const AuctionGiftTransactionEntity({
    required this.id,
    required this.priceUsd,
    required this.contributionUsd,
    required this.createdAt,
    required this.sender,
    required this.gift,
  });

  final String id;
  final double priceUsd;
  final double contributionUsd;
  final DateTime createdAt;
  final AuctionUserEntity sender;
  final AuctionGiftSummaryEntity gift;

  @override
  List<Object?> get props =>
      [id, priceUsd, contributionUsd, createdAt, sender, gift];
}

class AuctionDetailsEntity extends Equatable {
  const AuctionDetailsEntity({
    required this.id,
    required this.itemName,
    required this.targetPriceUsd,
    required this.currentTotalUsd,
    required this.status,
    required this.host,
    this.winner,
    required this.giftTransactions,
  });

  final String id;
  final String itemName;
  final double targetPriceUsd;
  final double currentTotalUsd;
  final String status;
  final AuctionUserEntity host;
  final AuctionUserEntity? winner;
  final List<AuctionGiftTransactionEntity> giftTransactions;

  @override
  List<Object?> get props => [
        id,
        itemName,
        targetPriceUsd,
        currentTotalUsd,
        status,
        host,
        winner,
        giftTransactions,
      ];
}
