import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';

class AuctionDetailsModel extends AuctionDetailsEntity {
  const AuctionDetailsModel({
    required super.id,
    required super.itemName,
    required super.targetPriceUsd,
    required super.currentTotalUsd,
    required super.status,
    required super.host,
    super.winner,
    required super.giftTransactions,
  });

  factory AuctionDetailsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    return AuctionDetailsModel(
      id: data['id']?.toString() ?? '',
      itemName: data['itemName']?.toString() ?? '',
      targetPriceUsd: _readDouble(data['targetPriceUsd']),
      currentTotalUsd: _readDouble(data['currentTotalUsd']),
      status: data['status']?.toString() ?? '',
      host: _parseUser(data['host']),
      winner: data['winner'] is Map
          ? _parseUser(Map<String, dynamic>.from(data['winner'] as Map))
          : null,
      giftTransactions: _parseTransactions(data['giftTransactions']),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
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
      priceUsd: 0,
    );
    if (giftRaw is Map) {
      final giftJson = Map<String, dynamic>.from(giftRaw);
      gift = AuctionGiftSummaryEntity(
        id: giftJson['id']?.toString() ?? '',
        name: giftJson['name']?.toString() ?? 'Gift',
        thumbnailUrl: giftJson['thumbnailUrl']?.toString(),
        priceUsd: _readDouble(giftJson['priceUsd'] ?? giftJson['price']),
      );
    }

    return AuctionGiftTransactionEntity(
      id: json['id']?.toString() ?? '',
      priceUsd: _readDouble(json['priceUsd']),
      contributionUsd: _readDouble(json['contributionUsd']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      sender: _parseUser(json['sender']),
      gift: gift,
    );
  }
}
