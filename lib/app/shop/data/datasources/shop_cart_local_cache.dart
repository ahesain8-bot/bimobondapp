import 'dart:convert';

import 'package:bimobondapp/app/shop/data/models/shop_models.dart';
import 'package:bimobondapp/app/shop/domain/entities/cart_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopCartLocalCache {
  ShopCartLocalCache({required SharedPreferences sharedPreferences})
      : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static const _cartJsonKey = 'SHOP_CART_JSON';
  static const _cartCountKey = 'SHOP_CART_COUNT';

  Future<void> saveCart(CartEntity cart) async {
    final model = cart is CartModel
        ? cart
        : CartModel(
            id: cart.id,
            userId: cart.userId,
            items: cart.items,
            updatedAt: cart.updatedAt,
          );
    await _prefs.setString(_cartJsonKey, jsonEncode(_cartToJson(model)));
    await _prefs.setInt(_cartCountKey, cart.itemCount);
  }

  CartEntity? loadCart() {
    final raw = _prefs.getString(_cartJsonKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return CartModel.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  int loadCartCount() => _prefs.getInt(_cartCountKey) ?? 0;

  Future<void> clear() async {
    await _prefs.remove(_cartJsonKey);
    await _prefs.remove(_cartCountKey);
  }

  Map<String, dynamic> _cartToJson(CartModel cart) => {
        'id': cart.id,
        'userId': cart.userId,
        if (cart.updatedAt != null)
          'updatedAt': cart.updatedAt!.toIso8601String(),
        'items': cart.items.map(_cartItemToJson).toList(),
      };

  Map<String, dynamic> _cartItemToJson(CartItemEntity item) {
    final product = item.product;
    return {
      'id': item.id,
      'productId': item.productId,
      if (item.variantId != null) 'variantId': item.variantId,
      'quantity': item.quantity,
      if (product != null)
        'product': {
          'id': product.id,
          'sellerId': product.sellerId,
          'title': product.title,
          'priceCoins': product.priceCoins,
          if (product.compareAtCoins != null)
            'compareAtCoins': product.compareAtCoins,
          if (product.coverImageUrl != null)
            'coverImageUrl': product.coverImageUrl,
          if (product.thumbnailUrl != null)
            'thumbnailUrl': product.thumbnailUrl,
        },
    };
  }
}
