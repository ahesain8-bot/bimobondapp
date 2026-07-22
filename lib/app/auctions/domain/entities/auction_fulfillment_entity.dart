import 'package:equatable/equatable.dart';

/// Response of GET /auctions/:id/fulfillment.
class AuctionFulfillmentEntity extends Equatable {
  const AuctionFulfillmentEntity({
    required this.auctionId,
    required this.status,
    required this.fulfillmentStatus,
    this.shippedAt,
    this.deliveredAt,
    this.sellerAcceptedAt,
    this.winnerAcceptedAt,
    this.settledAt,
    this.trackingNumber,
    this.shippingNote,
    this.winnerId,
    this.hostId,
  });

  final String auctionId;
  final String status;
  final String fulfillmentStatus;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? sellerAcceptedAt;
  final DateTime? winnerAcceptedAt;
  final DateTime? settledAt;
  final String? trackingNumber;
  final String? shippingNote;
  final String? winnerId;
  final String? hostId;

  factory AuctionFulfillmentEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    DateTime? parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '');

    return AuctionFulfillmentEntity(
      auctionId: data['auctionId']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      fulfillmentStatus: data['fulfillmentStatus']?.toString() ?? 'NONE',
      shippedAt: parseDate(data['shippedAt']),
      deliveredAt: parseDate(data['deliveredAt']),
      sellerAcceptedAt: parseDate(data['sellerAcceptedAt']),
      winnerAcceptedAt: parseDate(data['winnerAcceptedAt']),
      settledAt: parseDate(data['settledAt']),
      trackingNumber: data['trackingNumber']?.toString(),
      shippingNote: data['shippingNote']?.toString(),
      winnerId: data['winnerId']?.toString(),
      hostId: data['hostId']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        auctionId,
        status,
        fulfillmentStatus,
        shippedAt,
        deliveredAt,
        sellerAcceptedAt,
        winnerAcceptedAt,
        settledAt,
        trackingNumber,
        shippingNote,
        winnerId,
        hostId,
      ];
}
