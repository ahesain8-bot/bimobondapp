import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';

/// In-memory metadata cache for template lists / recipes / categories.
///
/// Assets are NOT stored here — use [VideoTemplateAssetLoader] (lazy).
class VideoTemplatesLocalCache {
  VideoTemplatesLocalCache({
    this.recipeTtl = const Duration(minutes: 30),
    this.listTtl = const Duration(minutes: 5),
    this.categoryTtl = const Duration(minutes: 15),
    this.maxRecipes = 40,
  });

  final Duration recipeTtl;
  final Duration listTtl;
  final Duration categoryTtl;
  final int maxRecipes;

  final Map<String, _Timed<VideoTemplateRecipeEntity>> _recipes = {};
  final Map<String, _Timed<VideoTemplateCardEntity>> _cards = {};
  final Map<String, _Timed<List<VideoTemplateCardEntity>>> _lists = {};
  _Timed<List<TemplateCategoryEntity>>? _categories;

  static String recipeKey(String templateId, {required bool includeOverlays}) =>
      '$templateId|ov=${includeOverlays ? 1 : 0}';

  static String listKey({
    String? shelf,
    String? templateKind,
    String? categoryId,
    String? soundId,
    String? query,
    int limit = 40,
    int offset = 0,
  }) {
    return [
      shelf ?? 'catalog',
      'kind=${templateKind ?? ''}',
      'cat=${categoryId ?? ''}',
      'sound=${soundId ?? ''}',
      'q=${query ?? ''}',
      'l=$limit',
      'o=$offset',
    ].join('|');
  }

  VideoTemplateRecipeEntity? getRecipe(
    String templateId, {
    required bool includeOverlays,
    int? expectedVersion,
  }) {
    final entry = _recipes[recipeKey(templateId, includeOverlays: includeOverlays)];
    if (entry == null || entry.isExpired(recipeTtl)) {
      if (entry != null) {
        _recipes.remove(recipeKey(templateId, includeOverlays: includeOverlays));
      }
      return null;
    }
    if (expectedVersion != null &&
        expectedVersion > 0 &&
        entry.value.version != expectedVersion) {
      // Stale vs card/list version — force refetch.
      _recipes.remove(recipeKey(templateId, includeOverlays: includeOverlays));
      return null;
    }
    return entry.value;
  }

  void putRecipe(
    VideoTemplateRecipeEntity recipe, {
    required bool includeOverlays,
  }) {
    if (recipe.id.isEmpty) return;
    _recipes[recipeKey(recipe.id, includeOverlays: includeOverlays)] =
        _Timed(recipe);
    _evictRecipesIfNeeded();
    // Keep card projection warm.
    putCard(
      VideoTemplateCardEntity(
        id: recipe.id,
        name: recipe.name,
        coverUrl: recipe.coverUrl,
        previewVideoUrl: recipe.previewVideoUrl,
        templateKind: recipe.templateKind,
        slotCount: recipe.slotCount,
        duration: recipe.duration,
        width: recipe.width,
        height: recipe.height,
        fps: recipe.fps,
        useCount: recipe.useCount,
        version: recipe.version,
        categoryId: recipe.categoryId,
        category: recipe.category,
        musicId: recipe.musicId,
        music: recipe.music,
        soundId: recipe.soundId,
        sound: recipe.sound,
        soundSegmentId: recipe.soundSegmentId,
      ),
    );
  }

  VideoTemplateCardEntity? getCard(String templateId) {
    final entry = _cards[templateId];
    if (entry == null || entry.isExpired(listTtl)) {
      _cards.remove(templateId);
      return null;
    }
    return entry.value;
  }

  void putCard(VideoTemplateCardEntity card) {
    if (card.id.isEmpty) return;
    _cards[card.id] = _Timed(card);
  }

  void putCards(Iterable<VideoTemplateCardEntity> cards) {
    for (final c in cards) {
      putCard(c);
    }
  }

  List<VideoTemplateCardEntity>? getList(String key) {
    final entry = _lists[key];
    if (entry == null || entry.isExpired(listTtl)) {
      _lists.remove(key);
      return null;
    }
    return List<VideoTemplateCardEntity>.from(entry.value);
  }

  void putList(String key, List<VideoTemplateCardEntity> cards) {
    _lists[key] = _Timed(List<VideoTemplateCardEntity>.from(cards));
    putCards(cards);
    if (_lists.length > 24) {
      final oldest = _lists.entries.reduce(
        (a, b) => a.value.at.isBefore(b.value.at) ? a : b,
      );
      _lists.remove(oldest.key);
    }
  }

  List<TemplateCategoryEntity>? getCategories() {
    final entry = _categories;
    if (entry == null || entry.isExpired(categoryTtl)) {
      _categories = null;
      return null;
    }
    return List<TemplateCategoryEntity>.from(entry.value);
  }

  void putCategories(List<TemplateCategoryEntity> categories) {
    _categories = _Timed(List<TemplateCategoryEntity>.from(categories));
  }

  /// Drop recipe caches when a newer version is known.
  void invalidateTemplate(String templateId, {int? newerVersion}) {
    _recipes.removeWhere((k, _) => k.startsWith('$templateId|'));
    if (newerVersion != null) {
      final card = _cards[templateId]?.value;
      if (card != null && card.version < newerVersion) {
        _cards.remove(templateId);
      }
    } else {
      _cards.remove(templateId);
    }
  }

  void clearLists() => _lists.clear();

  void clearAll() {
    _recipes.clear();
    _cards.clear();
    _lists.clear();
    _categories = null;
  }

  void _evictRecipesIfNeeded() {
    while (_recipes.length > maxRecipes) {
      final oldest = _recipes.entries.reduce(
        (a, b) => a.value.at.isBefore(b.value.at) ? a : b,
      );
      _recipes.remove(oldest.key);
    }
  }
}

class _Timed<T> {
  _Timed(this.value) : at = DateTime.now();

  final T value;
  final DateTime at;

  bool isExpired(Duration ttl) => DateTime.now().difference(at) > ttl;
}
