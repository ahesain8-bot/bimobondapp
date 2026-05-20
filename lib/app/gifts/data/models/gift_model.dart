import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';

class GiftModel extends GiftEntity {
  const GiftModel({
    required super.id,
    required super.name,
    required super.icon,
    required super.priceUsd,
    super.imageUrl,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? json['giftId'])?.toString() ?? '';
    final name = (json['name'] ?? json['title'] ?? json['label'] ?? '')
        .toString();

    String? imageUrl;
    for (final key in ['imageUrl', 'image', 'thumbnailUrl', 'thumbnail']) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        imageUrl = value;
        break;
      }
    }

    var icon = (json['icon'] ?? json['emoji'] ?? json['symbol'] ?? '')
        .toString();
    if (icon.isEmpty && imageUrl != null) {
      icon = imageUrl;
    }
    if (icon.isEmpty) {
      icon = '🎁';
    }

    final priceUsd = _readDouble(
      json['priceUsd'] ?? json['price'] ?? json['cost'] ?? json['amount'] ?? 0,
    );

    return GiftModel(
      id: id,
      name: name.isEmpty ? 'Gift' : name,
      icon: icon,
      priceUsd: priceUsd,
      imageUrl: imageUrl,
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class GiftInventoryItemModel extends GiftInventoryItemEntity {
  const GiftInventoryItemModel({
    required super.giftId,
    required super.quantity,
    super.gift,
  });

  factory GiftInventoryItemModel.fromJson(Map<String, dynamic> json) {
    final nestedGift = json['gift'];
    GiftEntity? gift;
    if (nestedGift is Map<String, dynamic>) {
      gift = GiftModel.fromJson(nestedGift);
    }

    final giftId = (json['giftId'] ??
            json['id'] ??
            gift?.id ??
            (nestedGift is Map ? nestedGift['id'] : null))
        ?.toString();

    return GiftInventoryItemModel(
      giftId: giftId ?? '',
      quantity: GiftModel._readInt(
        json['quantity'] ?? json['count'] ?? json['qty'] ?? 0,
      ),
      gift: gift,
    );
  }
}

class GiftInventoryModel extends GiftInventoryEntity {
  const GiftInventoryModel({
    required super.coinBalance,
    required super.items,
  });

  factory GiftInventoryModel.fromJson(Map<String, dynamic> json) {
    return GiftInventoryModel.fromApiResponse(json);
  }

  /// Parses purchase/send payloads and GET inventory responses.
  ///
  /// Purchase example:
  /// `{ "success": true, "newBalance": 19970, "inventory": { "giftId": "...", "quantity": 3 } }`
  factory GiftInventoryModel.fromApiResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return GiftInventoryModel.fromApiResponse(data);
    }

    final items = _parseItems(json);
    return GiftInventoryModel(
      coinBalance: _readBalance(json),
      items: items,
    );
  }

  /// Applies a partial server update (e.g. after purchase) onto existing state.
  static GiftInventoryModel merge(
    GiftInventoryEntity? current,
    GiftInventoryModel update,
  ) {
    final byGiftId = <String, GiftInventoryItemEntity>{
      for (final item in current?.items ?? []) item.giftId: item,
    };
    for (final item in update.items) {
      if (item.quantity <= 0) {
        byGiftId.remove(item.giftId);
      } else {
        byGiftId[item.giftId] = item;
      }
    }
    return GiftInventoryModel(
      coinBalance: update.coinBalance > 0
          ? update.coinBalance
          : (current?.coinBalance ?? 0),
      items: byGiftId.values.toList(),
    );
  }

  static List<GiftInventoryItemModel> _parseItems(Map<String, dynamic> json) {
    final items = <GiftInventoryItemModel>[];

    void addFromDynamic(dynamic value) {
      if (value is Map) {
        final item = GiftInventoryItemModel.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (item.giftId.isNotEmpty) items.add(item);
      } else if (value is List) {
        for (final entry in value) {
          addFromDynamic(entry);
        }
      }
    }

    for (final key in ['items', 'gifts', 'inventory', 'inventories']) {
      final value = json[key];
      if (value != null) {
        addFromDynamic(value);
      }
    }

    return items;
  }

  static int _readBalance(Map<String, dynamic> json) {
    for (final key in [
      'newBalance',
      'coinBalance',
      'coins',
      'balance',
      'walletBalance',
      'totalCoins',
    ]) {
      final value = json[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}
