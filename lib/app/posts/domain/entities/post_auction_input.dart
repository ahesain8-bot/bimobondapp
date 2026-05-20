import 'package:equatable/equatable.dart';

class PostAuctionInput extends Equatable {
  const PostAuctionInput({
    required this.itemName,
    this.itemImageUrl,
    required this.startingPriceUsd,
    required this.targetPriceUsd,
    required this.startedAt,
    required this.endedAt,
  });

  final String itemName;
  final String? itemImageUrl;
  final double startingPriceUsd;
  final double targetPriceUsd;
  final DateTime startedAt;
  final DateTime endedAt;

  PostAuctionInput copyWith({String? itemImageUrl}) {
    return PostAuctionInput(
      itemName: itemName,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      startingPriceUsd: startingPriceUsd,
      targetPriceUsd: targetPriceUsd,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'itemImageUrl': itemImageUrl,
        'startingPriceUsd': startingPriceUsd,
        'targetPriceUsd': targetPriceUsd,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        itemName,
        itemImageUrl,
        startingPriceUsd,
        targetPriceUsd,
        startedAt,
        endedAt,
      ];
}
