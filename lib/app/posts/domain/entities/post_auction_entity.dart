import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_entity.dart';
import 'package:equatable/equatable.dart';

class PostAuctionEntity extends Equatable {
  const PostAuctionEntity({
    this.id,
    required this.itemName,
    this.itemImageUrl,
    required this.startingPrice,
    required this.targetPrice,
    this.startingPriceCoins = 0,
    this.targetPriceCoins = 0,
    this.currentTotalCoins = 0,
    this.currencyCode = 'USD',
    this.giftCount = 0,
    this.status,
    this.pricing,
    required this.startedAt,
    required this.endedAt,
  });

  final String? id;
  final String itemName;
  final String? itemImageUrl;
  final double startingPrice;
  final double targetPrice;
  final int startingPriceCoins;
  final int targetPriceCoins;
  final int currentTotalCoins;
  final String currencyCode;
  final int giftCount;
  final String? status;
  final AuctionPricingEntity? pricing;
  final DateTime startedAt;
  final DateTime endedAt;

  double get progressPercent {
    if (pricing != null && pricing!.progressPercent > 0) {
      return pricing!.progressPercent.clamp(0, 100);
    }
    if (targetPriceCoins <= 0) return 0;
    return (displayHighestPriceCoins / targetPriceCoins * 100).clamp(0, 100);
  }

  bool get isTargetReached =>
      targetPriceCoins > 0 && displayHighestPriceCoins >= targetPriceCoins;

  /// Gift coins contributed on this auction (excludes starting price).
  int get giftContributionCoins => currentTotalCoins;

  /// Highest price shown in UI: starting price + gift contributions.
  int get displayHighestPriceCoins =>
      startingPriceCoins + giftContributionCoins;

  /// Shown in the "highest price" slot across feed, cards, and live view.
  int get displayHostEarningsCoins => displayHighestPriceCoins;

  /// Shown in the "target price" slot — always coin goal, never fiat.
  double get displayBidderSpendCoins {
    final estimated = pricing?.estimatedBidderSpendCoins;
    if (estimated != null && estimated > 0) return estimated;
    if (targetPriceCoins > 0) return targetPriceCoins.toDouble();
    final rate = pricing?.coinsPerPriceUnit ?? 0;
    if (rate > 0 && targetPrice > 0) return targetPrice * rate;
    return 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory PostAuctionEntity.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['itemImageUrl'];
    final pricingRaw = json['pricing'];
    final pricing = pricingRaw is Map
        ? AuctionPricingEntity.fromJson(pricingRaw)
        : null;

    final startingPrice = _readDouble(
      json['startingPrice'] ?? json['startingPriceUsd'],
    );
    final targetPrice = _readDouble(
      json['targetPrice'] ?? json['targetPriceUsd'],
    );

    // Never treat fiat/USD fields as coin amounts.
    final startingPriceCoins = _resolveCoins(
      explicit: json['startingPriceCoins'],
      fiat: startingPrice,
      coinsPerUnit: pricing?.coinsPerPriceUnit,
    );
    final targetPriceCoins = _resolveCoins(
      explicit: json['targetPriceCoins'],
      fiat: targetPrice,
      coinsPerUnit: pricing?.coinsPerPriceUnit,
      fallbackCoins: pricing?.estimatedHostEarningsCoins,
    );
    final currentTotalCoins = _readInt(json['currentTotalCoins']);

    return PostAuctionEntity(
      id: (json['id'] ?? json['auctionId'])?.toString(),
      itemName: json['itemName']?.toString() ?? '',
      itemImageUrl: imageUrl == null || imageUrl.toString() == 'null'
          ? null
          : imageUrl.toString(),
      startingPrice: startingPrice,
      targetPrice: targetPrice,
      startingPriceCoins: startingPriceCoins,
      targetPriceCoins: targetPriceCoins,
      currentTotalCoins: currentTotalCoins,
      currencyCode: (json['currencyCode'] ?? 'USD').toString(),
      giftCount: _readInt(
        json['giftCount'] ??
            json['giftsCount'] ??
            json['totalGiftsCount'] ??
            (json['giftTransactions'] is List
                ? (json['giftTransactions'] as List).length
                : 0),
      ),
      status: json['status']?.toString(),
      pricing: pricing,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'].toString())
          : DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'].toString())
          : DateTime.now(),
    );
  }

  /// Prefer explicit coin fields; convert fiat only via [coinsPerUnit].
  static int _resolveCoins({
    required dynamic explicit,
    required double fiat,
    int? coinsPerUnit,
    int? fallbackCoins,
  }) {
    final fromField = _readInt(explicit);
    if (fromField > 0) return fromField;
    if (fallbackCoins != null && fallbackCoins > 0) return fallbackCoins;
    final rate = coinsPerUnit ?? 0;
    if (rate > 0 && fiat > 0) return (fiat * rate).round();
    return 0;
  }

  PostAuctionEntity copyWith({
    String? id,
    String? itemName,
    String? itemImageUrl,
    double? startingPrice,
    double? targetPrice,
    int? startingPriceCoins,
    int? targetPriceCoins,
    int? currentTotalCoins,
    String? currencyCode,
    int? giftCount,
    String? status,
    AuctionPricingEntity? pricing,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return PostAuctionEntity(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      startingPrice: startingPrice ?? this.startingPrice,
      targetPrice: targetPrice ?? this.targetPrice,
      startingPriceCoins: startingPriceCoins ?? this.startingPriceCoins,
      targetPriceCoins: targetPriceCoins ?? this.targetPriceCoins,
      currentTotalCoins: currentTotalCoins ?? this.currentTotalCoins,
      currencyCode: currencyCode ?? this.currencyCode,
      giftCount: giftCount ?? this.giftCount,
      status: status ?? this.status,
      pricing: pricing ?? this.pricing,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    itemName,
    itemImageUrl,
    startingPrice,
    targetPrice,
    startingPriceCoins,
    targetPriceCoins,
    currentTotalCoins,
    currencyCode,
    giftCount,
    status,
    pricing,
    startedAt,
    endedAt,
  ];
}
