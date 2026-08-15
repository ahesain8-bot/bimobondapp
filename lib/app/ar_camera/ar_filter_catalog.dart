import 'package:bimobondapp/app/ar_camera/ar_color_filter_bundled_catalog.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filter_catalog_model.dart';
import 'package:bimobondapp/app/ar_camera/ar_overlay_bundled_catalog.dart';
import 'package:bimobondapp/app/ar_camera/ar_overlay_catalog_model.dart';

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

  /// Hardcoded effects that ship with the app, as opposed to the backend-driven
  /// screen overlays below.
  ///
  /// The PNG stickers (Glasses, Shades, Dog, Moustache, Mask) and the GPU warp
  /// distortions (Big Eyes, Big Lips, Nose) are commented out rather than
  /// deleted: the carousel is meant to carry only dynamic content now, but the
  /// native rendering code behind them is still in place and can be brought
  /// back by uncommenting these lines. The sticker PNG assets themselves were
  /// removed, so restoring the sticker entries also needs those drawables back
  /// (see StickerCatalog).
  ///
  /// Nose is a special case worth knowing about: the `long_nose` carousel entry
  /// is gone, but the nose-warp shader stays wired to the Face retouch slider,
  /// which is a separate feature.
  static const List<ArFilterItem> nativeEffectItems = [
    original,
    // ArFilterItem(id: 'glasses', label: 'Glasses', emoji: '😎'),
    // ArFilterItem(id: 'shades', label: 'Shades', emoji: '🕶️'),
    // ArFilterItem(id: 'dog', label: 'Dog', emoji: '🐶'),
    // ArFilterItem(id: 'moustache', label: 'Moustache', emoji: '🥸'),
    // ArFilterItem(id: 'mask', label: 'Mask', emoji: '💀'),
    // ArFilterItem(id: 'big_eyes', label: 'Big Eyes', emoji: '👀'),
    // ArFilterItem(id: 'big_lips', label: 'Big Lips', emoji: '👄'),
    // ArFilterItem(id: 'long_nose', label: 'Nose', emoji: '👃'),
  ];

  /// Screen-overlay (full-screen Lottie) catalog. Starts on the bundled
  /// fallback and is replaced by [updateOverlayCatalog] once
  /// `/camera-studio/ar-overlays` responds.
  static ArOverlayCatalog overlayCatalog = ArOverlayBundledCatalog.catalog;

  static void updateOverlayCatalog(ArOverlayCatalog catalog) {
    final mergedCategories = <ArOverlayCategoryModel>[];
    mergedCategories.addAll(catalog.categories);

    final existingIds = {
      for (final c in catalog.categories)
        for (final o in c.overlays) o.id
    };

    final missingBundledOverlays = <ArOverlayItemModel>[];
    for (final bundled in ArOverlayBundledCatalog.catalog.overlays) {
      if (!existingIds.contains(bundled.id)) {
        missingBundledOverlays.add(bundled);
      }
    }

    if (missingBundledOverlays.isNotEmpty) {
      if (mergedCategories.isNotEmpty) {
        final firstCategory = mergedCategories.first;
        mergedCategories[0] = ArOverlayCategoryModel(
          id: firstCategory.id,
          label: firstCategory.label,
          sortOrder: firstCategory.sortOrder,
          overlays: [...firstCategory.overlays, ...missingBundledOverlays],
        );
      } else {
        mergedCategories.add(ArOverlayCategoryModel(
          id: 'bundled',
          label: 'Bundled',
          sortOrder: 0,
          overlays: missingBundledOverlays,
        ));
      }
    }

    overlayCatalog = ArOverlayCatalog(
      version: catalog.version,
      categories: mergedCategories,
    );
    _overlayItemsCache = null;
  }

  static void restoreBundledOverlayCatalog() {
    overlayCatalog = ArOverlayBundledCatalog.catalog;
    _overlayItemsCache = null;
  }

  static ArOverlayItemModel? overlayById(String id) =>
      overlayCatalog.findOverlay(id);

  static List<ArFilterItem>? _overlayItemsCache;

  static List<ArFilterItem> get overlayItems => _overlayItemsCache ??= [
    for (final overlay in overlayCatalog.overlays)
      ArFilterItem(
        id: overlay.id,
        label: overlay.label,
        emoji: overlay.emoji ?? '',
        thumbnailUrl: overlay.thumbnailUrl,
        previewColorHex: overlay.previewColorHex,
      ),
  ];

  /// Carousel order: fixed native effects first, then whatever overlays the
  /// backend currently publishes.
  static List<ArFilterItem> get effectItems => [
    ...nativeEffectItems,
    ...overlayItems,
  ];

  /// Static beauty catalog (no LUTs).
  static ArColorFilterCatalog colorCatalog =
      ArColorFilterBundledCatalog.catalog;

  static void updateColorCatalog(ArColorFilterCatalog catalog) {
    colorCatalog = catalog.withValidBeautyOnly();
    _colorItemsCache = null;
    _colorCategoriesCache = null;
  }

  static void restoreBundledColorCatalog() {
    colorCatalog = ArColorFilterBundledCatalog.catalog;
    _colorItemsCache = null;
    _colorCategoriesCache = null;
  }

  static ArColorFilterItemModel? colorFilterById(String id) =>
      colorCatalog.findFilter(id);

  static bool isBeautyColorFilter(String id) =>
      colorFilterById(id)?.isBeauty ?? false;

  static List<ArFilterItem>? _colorItemsCache;
  static List<ArColorFilterCategory>? _colorCategoriesCache;

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

  static List<ArFilterItem> get items => [...effectItems, ...colorItems];

  static int indexOfId(String id) {
    final index = items.indexWhere((item) => item.id == id);
    return index < 0 ? 0 : index;
  }

  static ArFilterItem byId(String id) {
    return items.firstWhere((item) => item.id == id, orElse: () => original);
  }

  static bool isColorFilter(String id) =>
      colorItems.any((item) => item.id == id);

  static List<ArFilterItem> colorItemsForCategory(String categoryId) {
    if (colorCategories.isEmpty) return const [];
    final category = colorCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => colorCategories.first,
    );
    return [for (final id in category.filterIds) byId(id)];
  }

  static int effectCarouselIndex(String filterId) {
    final index = effectItems.indexWhere((item) => item.id == filterId);
    return index < 0 ? 0 : index;
  }

  /// Full-screen Lottie overlays. Now driven entirely by [overlayCatalog] —
  /// the native side no longer has a hardcoded id set of its own, it's told
  /// which animation to play when the filter is selected. These only make
  /// sense baked into a recorded video; there's no photo-capture path for
  /// them, so they're hidden from the carousel in photo mode.
  static bool isScreenOverlay(String id) => overlayById(id) != null;

  /// [effectItems], with screen-overlay filters excluded when [photoMode] is
  /// true. Use this (and [effectCarouselIndexFor]) together wherever the
  /// carousel is built so the displayed list and its selected index always
  /// agree — see `CameraStudioOverlay.build()`.
  static List<ArFilterItem> effectItemsFor({required bool photoMode}) {
    if (!photoMode) return effectItems;
    return [
      for (final item in effectItems)
        if (!isScreenOverlay(item.id)) item,
    ];
  }

  static int effectCarouselIndexFor(
    String filterId, {
    required bool photoMode,
  }) {
    final list = effectItemsFor(photoMode: photoMode);
    final index = list.indexWhere((item) => item.id == filterId);
    return index < 0 ? 0 : index;
  }
}
