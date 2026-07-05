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
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return AuctionPricingPreviewModel.fromJson(data);
    }

    final pricingRaw = json['pricing'];
    return AuctionPricingPreviewModel(
      targetPriceCoins: _readInt(json['targetPriceCoins'] ?? json['targetCoins']),
      targetPrice: _readDouble(json['targetPrice']),
      currencyCode: (json['currencyCode'] ?? 'USD').toString().toUpperCase(),
      currentTotalCoins: _readInt(json['currentTotalCoins']),
      pricing: pricingRaw != null
          ? AuctionPricingEntity.fromJson(pricingRaw)
          : const AuctionPricingEntity(),
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
