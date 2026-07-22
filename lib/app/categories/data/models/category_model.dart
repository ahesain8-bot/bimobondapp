import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.slug,
    super.description,
    super.iconUrl,
    super.isActive = true,
    super.order = 0,
    super.parentId,
    super.parent,
    super.children = const [],
    super.createdAt,
    super.updatedAt,
  });

  factory CategoryModel.fromJson(
    Map<String, dynamic> json, {
    bool parseChildren = true,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    int parseOrder(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    CategoryEntity? parent;
    final parentRaw = json['parent'];
    if (parentRaw is Map) {
      parent = CategoryModel.fromJson(
        Map<String, dynamic>.from(parentRaw),
        parseChildren: false,
      );
    }

    final children = <CategoryEntity>[];
    if (parseChildren) {
      final childrenRaw = json['children'];
      if (childrenRaw is List) {
        for (final item in childrenRaw.whereType<Map>()) {
          final child = CategoryModel.fromJson(
            Map<String, dynamic>.from(item),
            parseChildren: false,
          );
          if (child.id.isNotEmpty) children.add(child);
        }
        children.sort((a, b) {
          final byOrder = a.order.compareTo(b.order);
          if (byOrder != 0) return byOrder;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }
    }

    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      iconUrl: json['iconUrl']?.toString(),
      isActive: json['isActive'] != false,
      order: parseOrder(json['order']),
      parentId: json['parentId']?.toString() ?? parent?.id,
      parent: parent,
      children: children,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
