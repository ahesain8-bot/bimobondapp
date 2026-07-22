import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';

class CategoryLookup {
  CategoryLookup._();

  static CategoryEntity? findById(
    String? categoryId,
    List<CategoryEntity> categories,
  ) {
    if (categoryId == null || categoryId.trim().isEmpty) return null;
    final lower = categoryId.trim().toLowerCase();
    for (final category in flattenCategories(categories)) {
      if (category.id.toLowerCase() == lower) return category;
    }
    return null;
  }

  static String? labelForId(
    String? categoryId,
    List<CategoryEntity> categories,
  ) =>
      findById(categoryId, categories)?.name;

  static String? slugForId(
    String? categoryId,
    List<CategoryEntity> categories,
  ) =>
      findById(categoryId, categories)?.slug;

  static bool matchesId(String? categoryId, Set<String> selectedIds) {
    if (selectedIds.isEmpty) return true;
    if (categoryId == null || categoryId.trim().isEmpty) return false;
    final lower = categoryId.trim().toLowerCase();
    return selectedIds.any((id) => id.toLowerCase() == lower);
  }
}
