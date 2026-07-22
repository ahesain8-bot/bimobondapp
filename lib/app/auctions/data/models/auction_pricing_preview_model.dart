import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';

class AuctionPricingPreviewModel extends AuctionPricingPreviewEntity {
  const AuctionPricingPreviewModel({
    required super.targetPriceCoins,
    required super.targetPrice,
    required super.currencyCode,
    super.currentTotalCoins,
    super.pricing,
  });

  factory AuctionPricingPreviewModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final resolved = data['resolved'] is Map
        ? Map<String, dynamic>.from(data['resolved'] as Map)
        : data;
    final pricingRaw = data['pricing'];
    final pricing = pricingRaw is Map
        ? AuctionPricingEntity.fromJson(pricingRaw)
        : const AuctionPricingEntity();

    final targetPriceCoins = _readInt(
      resolved['targetPriceCoins'] ??
          data['targetPriceCoins'] ??
          data['targetCoins'],
    );
    final targetPrice = _readDouble(
      resolved['targetPrice'] ??
          data['targetPrice'] ??
          pricing.targetPrice,
    );
    final currencyCode = (resolved['currencyCode'] ??
            data['currencyCode'] ??
            pricing.currencyCode ??
            'USD')
        .toString()
        .toUpperCase();

    return AuctionPricingPreviewModel(
      targetPriceCoins: targetPriceCoins,
      targetPrice: targetPrice,
      currencyCode: currencyCode,
      currentTotalCoins: _readInt(data['currentTotalCoins']),
      pricing: pricing,
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
