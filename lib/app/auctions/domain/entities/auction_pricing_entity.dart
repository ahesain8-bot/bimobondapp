import 'package:equatable/equatable.dart';

class AuctionPricingEntity extends Equatable {
  const AuctionPricingEntity({
    this.coinsPerPriceUnit,
    this.commissionPercent,
    this.currencyCode,
    this.targetPrice,
    this.startingPrice,
    this.estimatedHostEarningsCoins,
    this.estimatedHostEarningsPrice,
    this.estimatedBidderSpendCoins,
    this.estimatedBidderSpendPrice,
    this.remainingCoins,
    this.remainingPrice,
    this.progressPercent = 0,
  });

  final int? coinsPerPriceUnit;
  final double? commissionPercent;
  final String? currencyCode;
  final double? targetPrice;
  final double? startingPrice;
  final int? estimatedHostEarningsCoins;
  final double? estimatedHostEarningsPrice;
  final double? estimatedBidderSpendCoins;
  final double? estimatedBidderSpendPrice;
  final int? remainingCoins;
  final double? remainingPrice;
  final double progressPercent;

  factory AuctionPricingEntity.fromJson(dynamic raw) {
    if (raw is! Map) return const AuctionPricingEntity();
    final json = Map<String, dynamic>.from(raw);

    return AuctionPricingEntity(
      coinsPerPriceUnit: _readInt(json['coinsPerPriceUnit']),
      commissionPercent: _readDouble(json['commissionPercent']),
      currencyCode: json['currencyCode']?.toString(),
      targetPrice: _readDouble(json['targetPrice']),
      startingPrice: _readDouble(json['startingPrice']),
      estimatedHostEarningsCoins:
          _readInt(json['estimatedHostEarningsCoins']),
      estimatedHostEarningsPrice:
          _readDouble(json['estimatedHostEarningsPrice']),
      estimatedBidderSpendCoins:
          _readDouble(json['estimatedBidderSpendCoins']),
      estimatedBidderSpendPrice:
          _readDouble(json['estimatedBidderSpendPrice']),
      remainingCoins: _readInt(json['remainingCoins']),
      remainingPrice: _readDouble(json['remainingPrice']),
      progressPercent: _readDouble(json['progressPercent']),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
        coinsPerPriceUnit,
        commissionPercent,
        currencyCode,
        targetPrice,
        startingPrice,
        estimatedHostEarningsCoins,
        estimatedHostEarningsPrice,
        estimatedBidderSpendCoins,
        estimatedBidderSpendPrice,
        remainingCoins,
        remainingPrice,
        progressPercent,
      ];
}
