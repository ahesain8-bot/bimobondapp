import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_group_entity.dart';

class GiftGroupModel extends GiftGroupEntity {
  const GiftGroupModel({
    required super.id,
    required super.name,
    required super.slug,
    required super.sortOrder,
    required super.gifts,
    super.iconUrl,
  });

  factory GiftGroupModel.fromJson(Map<String, dynamic> json) {
    final giftsRaw = json['gifts'];
    final gifts = <GiftModel>[];
    if (giftsRaw is List) {
      for (final entry in giftsRaw) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final isActive = map['isActive'];
        if (isActive == false) continue;
        final gift = GiftModel.fromJson(map);
        if (gift.id.isNotEmpty) gifts.add(gift);
      }
    }

    gifts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final name = _readGroupName(json);

    return GiftGroupModel(
      id: (json['id'] ?? '').toString(),
      name: name,
      slug: (json['slug'] ?? json['id'] ?? '').toString(),
      sortOrder: GiftModel.readInt(json['sortOrder']),
      iconUrl: json['iconUrl']?.toString(),
      gifts: gifts,
    );
  }

  static String _readGroupName(Map<String, dynamic> json) {
    for (final key in [
      'name',
      'title',
      'label',
      'displayName',
      'groupName',
    ]) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }
}
