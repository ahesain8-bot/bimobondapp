import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';

class GiftModel extends GiftEntity {
  const GiftModel({
    required super.id,
    required super.name,
    required super.icon,
    required super.priceCoins,
    super.imageUrl,
    super.thumbnailUrl,
    super.animationUrl,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? json['giftId'])?.toString() ?? '';
    final name = (json['name'] ?? json['title'] ?? json['label'] ?? '')
        .toString();

    String? thumbnailUrl;
    for (final key in ['thumbnailUrl', 'thumbnail', 'imageUrl', 'image']) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        thumbnailUrl = value;
        break;
      }
    }

    final animationUrl = (json['animationUrl'] ?? json['animation_url'])
        ?.toString()
        .trim();

    var icon = (json['icon'] ?? json['emoji'] ?? json['symbol'] ?? '')
        .toString();
    if (icon.isEmpty && thumbnailUrl != null) {
      icon = thumbnailUrl;
    }
    if (icon.isEmpty) {
      icon = '🎁';
    }

    final priceCoins = _readInt(
      json['priceCoins'] ??
          json['priceUsd'] ??
          json['price'] ??
          json['cost'] ??
          json['amount'] ??
          0,
    );

    return GiftModel(
      id: id,
      name: name.isEmpty ? 'Gift' : name,
      icon: icon,
      priceCoins: priceCoins,
      imageUrl: thumbnailUrl,
      thumbnailUrl: thumbnailUrl,
      animationUrl:
          animationUrl != null && animationUrl.isNotEmpty ? animationUrl : null,
    );
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
            gift?.id ??
            (nestedGift is Map ? nestedGift['id'] : null) ??
            json['id'])
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
    required super.balanceCoins,
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
      balanceCoins: _readBalance(json),
      items: items,
    );
  }

  /// Parses `POST /gifts/send` 201 body:
  /// `{ ..., "senderInventory": { "giftId": "...", "quantity": 4 } }`.
  factory GiftInventoryModel.fromSendResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) {
      return GiftInventoryModel.fromSendResponse(
        Map<String, dynamic>.from(data),
      );
    }

    final raw = json['senderInventory'] ?? json['inventory'];
    if (raw is Map) {
      final item = GiftInventoryItemModel.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return GiftInventoryModel(
        balanceCoins: 0,
        items: item.giftId.isEmpty ? const [] : [item],
      );
    }

    return GiftInventoryModel.fromApiResponse(json);
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
      balanceCoins: update.balanceCoins > 0
          ? update.balanceCoins
          : (current?.balanceCoins ?? 0),
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

    for (final key in [
      'items',
      'gifts',
      'inventory',
      'inventories',
      'senderInventory',
    ]) {
      final value = json[key];
      if (value != null) {
        addFromDynamic(value);
      }
    }

    return items;
  }

  static int _readBalance(Map<String, dynamic> json) {
    for (final key in [
      'newBalanceCoins',
      'newBalance',
      'balanceCoins',
      'coinBalance',
      'coins',
      'balance',
      'walletBalance',
      'totalCoins',
      'balanceUsd',
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
