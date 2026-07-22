import 'package:equatable/equatable.dart';

/// Body for POST /auctions (or live create).
class CreateAuctionInput extends Equatable {
  const CreateAuctionInput({
    required this.targetPrice,
    this.postId,
    this.liveId,
    this.itemName,
    this.itemImageUrl,
    this.startingPrice,
    this.startedAt,
    this.endedAt,
  });

  final double targetPrice;
  final String? postId;
  final String? liveId;
  final String? itemName;
  final String? itemImageUrl;
  final double? startingPrice;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, dynamic> toJson() => {
        'targetPrice': targetPrice,
        if (postId != null && postId!.isNotEmpty) 'postId': postId,
        if (liveId != null && liveId!.isNotEmpty) 'liveId': liveId,
        if (itemName != null && itemName!.isNotEmpty) 'itemName': itemName,
        if (itemImageUrl != null && itemImageUrl!.isNotEmpty)
          'itemImageUrl': itemImageUrl,
        if (startingPrice != null) 'startingPrice': startingPrice,
        if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        targetPrice,
        postId,
        liveId,
        itemName,
        itemImageUrl,
        startingPrice,
        startedAt,
        endedAt,
      ];
}
