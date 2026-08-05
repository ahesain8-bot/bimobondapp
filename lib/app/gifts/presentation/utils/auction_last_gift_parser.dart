import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';

class PostAuctionLastGiftEntity {
  const PostAuctionLastGiftEntity({
    required this.id,
    required this.name,
    required this.type,
    this.color,
    this.quantity = 1,
  });

  final String id;
  final String name;
  final GiftCatalogType type;
  final String? color;
  final int quantity;

  bool get isAudioGift => type == GiftCatalogType.audio;

  static PostAuctionLastGiftEntity? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    return fromMap(Map<String, dynamic>.from(raw));
  }

  static PostAuctionLastGiftEntity? fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) return null;

    Map<String, dynamic> source = map;
    final nested = map['gift'];
    if (nested is Map) {
      source = Map<String, dynamic>.from(nested);
    }

    final id = (source['giftId'] ?? source['id'] ?? map['giftId'] ?? map['id'])
        ?.toString();
    final name = (source['name'] ?? map['name'])?.toString().trim() ?? '';
    if (name.isEmpty && (id == null || id.isEmpty)) return null;

    final rawQty = map['quantity'] ?? map['qty'] ?? source['quantity'] ?? source['qty'];
    final qty = rawQty is int ? rawQty : (int.tryParse('$rawQty') ?? 1);

    return PostAuctionLastGiftEntity(
      id: id ?? '',
      name: name.isEmpty ? 'Gift' : name,
      type: _parseType(source['type'] ?? map['type']),
      color: (source['color'] ?? map['color'])?.toString().trim(),
      quantity: qty > 0 ? qty : 1,
    );
  }

  static GiftCatalogType _parseType(dynamic raw) {
    final value = raw?.toString().toUpperCase();
    if (value == 'AUDIO') return GiftCatalogType.audio;
    return GiftCatalogType.image;
  }
}
