import 'package:bimobondapp/app/ar_camera/ar_color_filter_bundled_catalog.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filter_catalog_model.dart';

class ArFilterItem {
  const ArFilterItem({
    required this.id,
    required this.label,
    required this.emoji,
    this.thumbnailUrl,
    this.previewColorHex,
  });

  final String id;
  final String label;
  final String emoji;

  final String? thumbnailUrl;

  final String? previewColorHex;

  bool get hasThumbnail => (thumbnailUrl ?? '').isNotEmpty;

  bool get isOriginal => id == 'none';
}

class ArColorFilterCategory {
  const ArColorFilterCategory({
    required this.id,
    required this.label,
    required this.filterIds,
  });

  final String id;
  final String label;
  final List<String> filterIds;
}

class ArFilterCatalog {
  ArFilterCatalog._();

  static const original = ArFilterItem(
    id: 'none',
    label: 'Original',
    emoji: '✨',
  );

  static const List<ArFilterItem> effectItems = [
    original,
    ArFilterItem(id: 'glasses', label: 'Glasses', emoji: '😎'),
    ArFilterItem(id: 'shades', label: 'Shades', emoji: '🕶️'),
    ArFilterItem(id: 'dog', label: 'Dog', emoji: '🐶'),
    ArFilterItem(id: 'moustache', label: 'Moustache', emoji: '🥸'),
    ArFilterItem(id: 'mask', label: 'Mask', emoji: '💀'),
    ArFilterItem(id: 'big_eyes', label: 'Big Eyes', emoji: '👀'),
    ArFilterItem(id: 'big_lips', label: 'Big Lips', emoji: '👄'),
    ArFilterItem(id: 'long_nose', label: 'Nose', emoji: '👃'),
  ];

  // STATIC catalog (bundled LUT filters).
  static ArColorFilterCatalog colorCatalog =
      ArColorFilterBundledCatalog.catalog;

  // DYNAMIC API — temporarily disabled.
  static void updateColorCatalog(ArColorFilterCatalog catalog) {
    // colorCatalog = catalog;
    // _colorItemsCache = null;
    // _colorCategoriesCache = null;
  }

  static void restoreBundledColorCatalog() {
    colorCatalog = ArColorFilterBundledCatalog.catalog;
    _colorItemsCache = null;
    _colorCategoriesCache = null;
  }

  static List<ArFilterItem>? _colorItemsCache;
  static List<ArColorFilterCategory>? _colorCategoriesCache;

  static List<ArFilterItem> get colorItems => _colorItemsCache ??= [
        for (final category in colorCatalog.categories)
          for (final filter in category.filters)
            ArFilterItem(
              id: filter.id,
              label: filter.label,
              emoji: filter.emoji ?? '',
              thumbnailUrl: (filter.thumbnailUrl ?? '').isEmpty
                  ? null
                  : filter.thumbnailUrl,
              previewColorHex: filter.previewColorHex,
            ),
      ];

  static List<ArColorFilterCategory> get colorCategories =>
      _colorCategoriesCache ??= [
        for (final category in colorCatalog.categories)
          ArColorFilterCategory(
            id: category.id,
            label: category.label,
            filterIds: [for (final f in category.filters) f.id],
          ),
      ];

  static List<ArFilterItem> get items => [
        ...effectItems,
        ...colorItems,
      ];

  static int indexOfId(String id) {
    final index = items.indexWhere((item) => item.id == id);
    return index < 0 ? 0 : index;
  }

  static ArFilterItem byId(String id) {
    return items.firstWhere(
      (item) => item.id == id,
      orElse: () => original,
    );
  }

  static bool isColorFilter(String id) =>
      colorItems.any((item) => item.id == id);

  static ArColorFilterItemModel? colorFilterModelForId(String id) {
    for (final category in colorCatalog.categories) {
      for (final filter in category.filters) {
        if (filter.id == id) return filter;
      }
    }
    return null;
  }

  static String? pngLutUrlForId(String id) {
    for (final category in colorCatalog.categories) {
      for (final filter in category.filters) {
        if (filter.id != id) continue;
        final url = filter.lutUrl?.trim();
        if (url != null &&
            url.isNotEmpty &&
            url.split('?').first.toLowerCase().endsWith('.png')) {
          return url;
        }
        return null;
      }
    }
    return null;
  }

  static List<ArFilterItem> colorItemsForCategory(String categoryId) {
    if (colorCategories.isEmpty) return const [];
    final category = colorCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => colorCategories.first,
    );
    return [
      for (final id in category.filterIds) byId(id),
    ];
  }

  static int effectCarouselIndex(String filterId) {
    final index = effectItems.indexWhere((item) => item.id == filterId);
    return index < 0 ? 0 : index;
  }
}
