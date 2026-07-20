import 'package:bimobondapp/app/ar_camera/ar_color_filter_catalog_model.dart';

/// Shared AR filter / effect catalog used by test screen and main camera.
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

  /// Server-provided preview image. When present the carousel shows this
  /// instead of [emoji]; [emoji] stays only as an offline fallback.
  final String? thumbnailUrl;

  /// Optional solid color placeholder (behind the thumbnail while it loads).
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

  /// Stickers + face warp — shown in the bottom shutter carousel.
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

  /// Source of truth for the color grades. Currently the bundled (offline)
  /// catalog; swap this for the server-fetched [ArColorFilterCatalog] later
  /// and the whole UI + matrices follow automatically.
  static ArColorFilterCatalog colorCatalog = ArColorFilterCatalog.bundled();

  /// Replace the active color catalog (e.g. once fetched from the server) and
  /// drop the cached derived lists so they rebuild from the new data.
  static void updateColorCatalog(ArColorFilterCatalog catalog) {
    colorCatalog = catalog;
    _colorItemsCache = null;
    _colorCategoriesCache = null;
  }

  static List<ArFilterItem>? _colorItemsCache;
  static List<ArColorFilterCategory>? _colorCategoriesCache;

  /// Color / portrait-style grades — TikTok Filters sheet only.
  /// Derived from [colorCatalog] so there is a single source of truth.
  static List<ArFilterItem> get colorItems => _colorItemsCache ??= [
        for (final category in colorCatalog.categories)
          for (final filter in category.filters)
            ArFilterItem(
              id: filter.id,
              label: filter.label,
              emoji: filter.emoji ?? '',
              thumbnailUrl: filter.thumbnailUrl,
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

  /// Flat list for lookups / MethodChannel ids.
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

  static List<ArFilterItem> colorItemsForCategory(String categoryId) {
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
