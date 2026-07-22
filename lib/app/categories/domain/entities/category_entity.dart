import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.isActive = true,
    this.order = 0,
    this.parentId,
    this.parent,
    this.children = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final bool isActive;
  final int order;
  final String? parentId;
  final CategoryEntity? parent;
  final List<CategoryEntity> children;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isMain => parentId == null || parentId!.isEmpty;

  /// Flat list of this node + descendants (depth 1 in practice).
  List<CategoryEntity> get selfAndChildren {
    if (children.isEmpty) return [this];
    return [this, ...children];
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        iconUrl,
        isActive,
        order,
        parentId,
        parent,
        children,
        createdAt,
        updatedAt,
      ];
}

/// Flattens a tree/list into selectable categories (mains + subs).
List<CategoryEntity> flattenCategories(List<CategoryEntity> categories) {
  final out = <CategoryEntity>[];
  final seen = <String>{};
  void add(CategoryEntity c) {
    if (c.id.isEmpty || !seen.add(c.id)) return;
    out.add(c);
    for (final child in c.children) {
      add(child);
    }
  }

  for (final c in categories) {
    add(c);
  }
  return out;
}
