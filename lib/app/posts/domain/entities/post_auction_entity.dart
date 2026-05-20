import 'package:equatable/equatable.dart';

class PostAuctionEntity extends Equatable {
  const PostAuctionEntity({
    this.id,
    required this.itemName,
    this.itemImageUrl,
    required this.startingPriceUsd,
    required this.targetPriceUsd,
    this.currentTotalUsd = 0,
    this.giftCount = 0,
    required this.startedAt,
    required this.endedAt,
  });

  final String? id;
  final String itemName;
  final String? itemImageUrl;
  final double startingPriceUsd;
  final double targetPriceUsd;

  /// Sum of gift contributions received for this auction/post.
  final double currentTotalUsd;

  /// Number of gifts sent on this auction.
  final int giftCount;
  final DateTime startedAt;
  final DateTime endedAt;

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
    return PostAuctionEntity(
      id: json['id']?.toString(),
      itemName: json['itemName']?.toString() ?? '',
      itemImageUrl: imageUrl == null || imageUrl.toString() == 'null'
          ? null
          : imageUrl.toString(),
      startingPriceUsd: (json['startingPriceUsd'] as num?)?.toDouble() ?? 0,
      targetPriceUsd: (json['targetPriceUsd'] as num?)?.toDouble() ?? 0,
      currentTotalUsd: _readDouble(
        json['currentTotalUsd'] ??
            json['giftTotalUsd'] ??
            json['totalGiftsUsd'],
      ),
      giftCount: _readInt(
        json['giftCount'] ??
            json['giftsCount'] ??
            json['totalGiftsCount'] ??
            (json['giftTransactions'] is List
                ? (json['giftTransactions'] as List).length
                : 0),
      ),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'].toString())
          : DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'].toString())
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        itemName,
        itemImageUrl,
        startingPriceUsd,
        targetPriceUsd,
        currentTotalUsd,
        giftCount,
        startedAt,
        endedAt,
      ];
}
