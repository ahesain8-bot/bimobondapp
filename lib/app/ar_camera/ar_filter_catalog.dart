/// Shared AR filter / effect catalog used by test screen and main camera.
class ArFilterItem {
  const ArFilterItem({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;

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
    ArFilterItem(id: 'dog', label: 'Dog', emoji: '🐶'),
    ArFilterItem(id: 'moustache', label: 'Moustache', emoji: '🥸'),
    ArFilterItem(id: 'big_eyes', label: 'Big Eyes', emoji: '👀'),
    ArFilterItem(id: 'big_lips', label: 'Big Lips', emoji: '👄'),
    ArFilterItem(id: 'long_nose', label: 'Nose', emoji: '👃'),
  ];

  /// Color / “white” portrait-style grades — TikTok Filters sheet only.
  static const List<ArFilterItem> colorItems = [
    ArFilterItem(id: 'whitening', label: 'Pure', emoji: '🤍'),
    ArFilterItem(id: 'clarendon', label: 'Bright', emoji: '☀️'),
    ArFilterItem(id: 'ludwig', label: 'Clean', emoji: '✨'),
    ArFilterItem(id: 'rosy', label: 'Soft', emoji: '🌸'),
    ArFilterItem(id: 'valencia', label: 'Sunset', emoji: '🌇'),
    ArFilterItem(id: 'warm', label: 'Warm', emoji: '🍑'),
    ArFilterItem(id: 'cool', label: 'Cool', emoji: '❄️'),
    ArFilterItem(id: 'vintage', label: 'Retro', emoji: '🎞️'),
    ArFilterItem(id: 'mono', label: 'B & W', emoji: '🖤'),
  ];

  static const List<ArColorFilterCategory> colorCategories = [
    ArColorFilterCategory(
      id: 'portrait',
      label: 'Portrait',
      filterIds: ['whitening', 'clarendon', 'ludwig', 'rosy', 'valencia'],
    ),
    ArColorFilterCategory(
      id: 'life',
      label: 'Life',
      filterIds: ['warm', 'cool'],
    ),
    ArColorFilterCategory(
      id: 'retro',
      label: 'Retro',
      filterIds: ['vintage', 'mono'],
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
