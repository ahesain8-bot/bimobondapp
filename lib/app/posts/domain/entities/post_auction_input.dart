import 'package:equatable/equatable.dart';

class PostAuctionInput extends Equatable {
  const PostAuctionInput({
    required this.itemName,
    this.itemImageUrl,
    required this.targetPrice,
    required this.startedAt,
    required this.endedAt,
    this.startingPrice,
  });

  final String itemName;
  final String? itemImageUrl;
  /// Optional; omit/null clears low starting price (API default 0).
  final double? startingPrice;
  final double targetPrice;
  final DateTime startedAt;
  final DateTime endedAt;

  PostAuctionInput copyWith({String? itemImageUrl}) {
    return PostAuctionInput(
      itemName: itemName,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      startingPrice: startingPrice,
      targetPrice: targetPrice,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        if (itemImageUrl != null) 'itemImageUrl': itemImageUrl,
        'targetPrice': targetPrice,
        if (startingPrice != null && startingPrice! > 0)
          'startingPrice': startingPrice,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        itemName,
        itemImageUrl,
        startingPrice,
        targetPrice,
        startedAt,
        endedAt,
      ];
}
