import 'package:equatable/equatable.dart';

/// Maps to auction-related query params on the feed API (`FeedQueryDto`).
class FeedAuctionQuery extends Equatable {
  const FeedAuctionQuery({
    this.isAuctionable,
    this.priceLower,
    this.priceUpper,
    this.startingPriceLower,
    this.startingPriceUpper,
    this.currentTotalLower,
    this.currentTotalUpper,
    this.targetDateFrom,
    this.targetDateTo,
    this.startedAtFrom,
    this.startedAtTo,
    this.auctionStatus,
    this.auctionHostId,
  });

  final bool? isAuctionable;
  final double? priceLower;
  final double? priceUpper;
  final double? startingPriceLower;
  final double? startingPriceUpper;
  final double? currentTotalLower;
  final double? currentTotalUpper;
  final DateTime? targetDateFrom;
  final DateTime? targetDateTo;
  final DateTime? startedAtFrom;
  final DateTime? startedAtTo;
  final String? auctionStatus;
  final String? auctionHostId;

  Map<String, dynamic> toQueryParams() {
    return {
      if (isAuctionable != null) 'isAuctionable': isAuctionable! ? 'true' : 'false',
      if (priceLower != null) 'priceLower': priceLower,
      if (priceUpper != null) 'priceUpper': priceUpper,
      if (startingPriceLower != null) 'startingPriceLower': startingPriceLower,
      if (startingPriceUpper != null) 'startingPriceUpper': startingPriceUpper,
      if (currentTotalLower != null) 'currentTotalLower': currentTotalLower,
      if (currentTotalUpper != null) 'currentTotalUpper': currentTotalUpper,
      if (targetDateFrom != null)
        'targetDateFrom': targetDateFrom!.toUtc().toIso8601String(),
      if (targetDateTo != null)
        'targetDateTo': targetDateTo!.toUtc().toIso8601String(),
      if (startedAtFrom != null)
        'startedAtFrom': startedAtFrom!.toUtc().toIso8601String(),
      if (startedAtTo != null)
        'startedAtTo': startedAtTo!.toUtc().toIso8601String(),
      if (auctionStatus != null) 'auctionStatus': auctionStatus,
      if (auctionHostId != null) 'auctionHostId': auctionHostId,
    };
  }

  @override
  List<Object?> get props => [
        isAuctionable,
        priceLower,
        priceUpper,
        startingPriceLower,
        startingPriceUpper,
        currentTotalLower,
        currentTotalUpper,
        targetDateFrom,
        targetDateTo,
        startedAtFrom,
        startedAtTo,
        auctionStatus,
        auctionHostId,
      ];
}
