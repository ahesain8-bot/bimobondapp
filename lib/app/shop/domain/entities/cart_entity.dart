import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

class CartItemEntity extends Equatable {
  const CartItemEntity({
    required this.id,
    required this.productId,
    required this.quantity,
    this.variantId,
    this.product,
    this.variant,
  });

  final String id;
  final String productId;
  final String? variantId;
  final int quantity;
  final ProductEntity? product;
  final ProductVariantEntity? variant;

  int get unitPriceCoins =>
      variant?.priceCoins ?? product?.priceCoins ?? 0;

  int get lineTotalCoins => unitPriceCoins * quantity;

  String? get imageUrl =>
      variant?.imageUrl ?? product?.displayImageUrl;

  String get title => product?.title ?? 'Product';

  @override
  List<Object?> get props =>
      [id, productId, variantId, quantity, product, variant];
}

class CartEntity extends Equatable {
  const CartEntity({
    required this.id,
    required this.userId,
    required this.items,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final List<CartItemEntity> items;
  final DateTime? updatedAt;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  int get subtotalCoins =>
      items.fold(0, (sum, i) => sum + i.lineTotalCoins);

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [id, userId, items, updatedAt];
}
