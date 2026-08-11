import 'package:shared_preferences/shared_preferences.dart';

/// Local favorite product IDs (no dedicated favorites API yet).
class ShopFavoritesLocalStore {
  ShopFavoritesLocalStore({required SharedPreferences sharedPreferences})
      : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static const _key = 'SHOP_FAVORITE_PRODUCT_IDS';

  Set<String> get ids {
    final list = _prefs.getStringList(_key) ?? const [];
    return list.toSet();
  }

  bool isFavorite(String productId) => ids.contains(productId);

  Future<bool> toggle(String productId) async {
    final next = ids;
    final favorite = !next.contains(productId);
    if (favorite) {
      next.add(productId);
    } else {
      next.remove(productId);
    }
    await _prefs.setStringList(_key, next.toList(growable: false));
    return favorite;
  }
}
