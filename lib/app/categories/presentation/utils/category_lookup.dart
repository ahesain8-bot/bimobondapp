import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';

class CategoryLookup {
  CategoryLookup._();

  static String? labelForId(
    String? categoryId,
    List<CategoryEntity> categories,
  ) {
    if (categoryId == null || categoryId.trim().isEmpty) return null;
    final lower = categoryId.trim().toLowerCase();
    for (final category in categories) {
      if (category.id.toLowerCase() == lower) return category.name;
    }
    return null;
  }

  static String? slugForId(
    String? categoryId,
    List<CategoryEntity> categories,
  ) {
    if (categoryId == null || categoryId.trim().isEmpty) return null;
    final lower = categoryId.trim().toLowerCase();
    for (final category in categories) {
      if (category.id.toLowerCase() == lower) return category.slug;
    }
    return null;
  }

  static bool matchesId(String? categoryId, Set<String> selectedIds) {
    if (selectedIds.isEmpty) return true;
    if (categoryId == null || categoryId.trim().isEmpty) return false;
    final lower = categoryId.trim().toLowerCase();
    return selectedIds.any((id) => id.toLowerCase() == lower);
  }
}
