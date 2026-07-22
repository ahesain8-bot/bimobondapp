import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_entity.dart';

class AuctionDetailsModel extends AuctionDetailsEntity {
  const AuctionDetailsModel({
    required super.id,
    required super.itemName,
    required super.targetPrice,
    required super.targetPriceCoins,
    required super.startingPriceCoins,
    required super.currentTotalCoins,
    required super.currencyCode,
    required super.status,
    required super.host,
    super.winner,
    required super.giftTransactions,
    super.pricing,
    super.postId,
    super.liveId,
    super.itemImageUrl,
    super.startingPrice,
    super.escrowEnabled,
    super.fulfillmentStatus,
    super.startedAt,
    super.endedAt,
    super.giftCount,
  });

  factory AuctionDetailsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final targetPrice = _readDouble(
      data['targetPrice'] ?? data['targetPriceUsd'],
    );
    final targetPriceCoins = _readInt(
      data['targetPriceCoins'] ?? data['targetPriceUsd'] ?? targetPrice.round(),
    );
    final startingPrice = _readDouble(
      data['startingPrice'] ?? data['startingPriceUsd'],
    );
    final startingPriceCoins = _readInt(
      data['startingPriceCoins'] ??
          data['startingPriceUsd'] ??
          startingPrice.round(),
    );
    final currentTotalCoins = _readInt(
      data['currentTotalCoins'] ??
          data['currentTotalUsd'] ??
          data['giftTotalUsd'],
    );
    final giftTransactions = _parseTransactions(data['giftTransactions']);
    final countRaw = data['_count'];
    final giftCount = countRaw is Map
        ? _readInt(countRaw['giftTransactions'] ?? countRaw['gifts'])
        : giftTransactions.length;

    return AuctionDetailsModel(
      id: data['id']?.toString() ?? '',
      itemName: data['itemName']?.toString() ?? '',
      targetPrice: targetPrice,
      targetPriceCoins: targetPriceCoins,
      startingPriceCoins: startingPriceCoins,
      currentTotalCoins: currentTotalCoins,
      currencyCode: (data['currencyCode'] ?? 'USD').toString(),
      status: data['status']?.toString() ?? '',
      host: _parseUser(data['host']),
      winner: data['winner'] is Map
          ? _parseUser(Map<String, dynamic>.from(data['winner'] as Map))
          : null,
      giftTransactions: giftTransactions,
      pricing: data['pricing'] is Map
          ? AuctionPricingEntity.fromJson(data['pricing'])
          : null,
      postId: data['postId']?.toString(),
      liveId: data['liveId']?.toString(),
      itemImageUrl: data['itemImageUrl']?.toString(),
      startingPrice: startingPrice,
      escrowEnabled: data['escrowEnabled'] == true,
      fulfillmentStatus: data['fulfillmentStatus']?.toString(),
      startedAt: DateTime.tryParse(data['startedAt']?.toString() ?? ''),
      endedAt: DateTime.tryParse(data['endedAt']?.toString() ?? ''),
      giftCount: giftCount,
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static AuctionUserEntity _parseUser(dynamic raw) {
    if (raw is! Map) {
      return const AuctionUserEntity(id: '');
    }
    final json = Map<String, dynamic>.from(raw);
    return AuctionUserEntity(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString(),
      fullName: json['fullName']?.toString() ?? json['name']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  static List<AuctionGiftTransactionEntity> _parseTransactions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => _parseTransaction(Map<String, dynamic>.from(e)))
        .where((tx) => tx.id.isNotEmpty)
        .toList();
  }

  static AuctionGiftTransactionEntity _parseTransaction(
    Map<String, dynamic> json,
  ) {
    final giftRaw = json['gift'];
    AuctionGiftSummaryEntity gift = const AuctionGiftSummaryEntity(
      id: '',
      name: 'Gift',
      priceCoins: 0,
    );
    if (giftRaw is Map) {
      final giftJson = Map<String, dynamic>.from(giftRaw);
      gift = AuctionGiftSummaryEntity(
        id: giftJson['id']?.toString() ?? '',
        name: giftJson['name']?.toString() ?? 'Gift',
        thumbnailUrl: giftJson['thumbnailUrl']?.toString(),
        priceCoins: _readInt(
          giftJson['priceCoins'] ?? giftJson['priceUsd'] ?? giftJson['price'],
        ),
      );
    }

    return AuctionGiftTransactionEntity(
      id: json['id']?.toString() ?? '',
      priceCoins: _readInt(json['priceCoins'] ?? json['priceUsd']),
      contributionCoins: _readInt(
        json['contributionCoins'] ?? json['contributionUsd'],
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      sender: _parseUser(json['sender']),
      gift: gift,
    );
  }
}
