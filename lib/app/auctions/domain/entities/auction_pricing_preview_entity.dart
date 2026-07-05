import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_entity.dart';
import 'package:equatable/equatable.dart';

class AuctionPricingPreviewEntity extends Equatable {
  const AuctionPricingPreviewEntity({
    required this.targetPriceCoins,
    required this.targetPrice,
    required this.currencyCode,
    this.currentTotalCoins = 0,
    this.pricing = const AuctionPricingEntity(),
  });

  final int targetPriceCoins;
  final double targetPrice;
  final String currencyCode;
  final int currentTotalCoins;
  final AuctionPricingEntity pricing;

  @override
  List<Object?> get props => [
        targetPriceCoins,
        targetPrice,
        currencyCode,
        currentTotalCoins,
        pricing,
      ];
}
