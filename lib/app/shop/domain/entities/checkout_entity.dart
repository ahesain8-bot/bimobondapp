import 'package:equatable/equatable.dart';

enum ProductPaymentMethod { coins, gifts, mixed }

class CheckoutLineEntity extends Equatable {
  const CheckoutLineEntity({
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPriceCoins,
    required this.lineTotalCoins,
    this.variantId,
    this.imageUrl,
  });

  final String productId;
  final String? variantId;
  final String title;
  final String? imageUrl;
  final int quantity;
  final int unitPriceCoins;
  final int lineTotalCoins;

  @override
  List<Object?> get props => [
        productId,
        variantId,
        title,
        imageUrl,
        quantity,
        unitPriceCoins,
        lineTotalCoins,
      ];
}

class CheckoutGiftPaymentInput extends Equatable {
  const CheckoutGiftPaymentInput({
    required this.giftId,
    required this.quantity,
  });

  final String giftId;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'giftId': giftId,
        'quantity': quantity,
      };

  @override
  List<Object?> get props => [giftId, quantity];
}

class CheckoutItemInput extends Equatable {
  const CheckoutItemInput({
    required this.productId,
    required this.quantity,
    this.variantId,
  });

  final String productId;
  final String? variantId;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        if (variantId != null && variantId!.isNotEmpty) 'variantId': variantId,
      };

  @override
  List<Object?> get props => [productId, variantId, quantity];
}

class ShippingAddressInput extends Equatable {
  const ShippingAddressInput({
    required this.name,
    required this.line1,
    required this.city,
    required this.country,
    this.phone,
    this.line2,
    this.postalCode,
  });

  final String name;
  final String line1;
  final String? line2;
  final String city;
  final String country;
  final String? phone;
  final String? postalCode;

  Map<String, dynamic> toJson() => {
        'name': name,
        'line1': line1,
        if (line2 != null && line2!.isNotEmpty) 'line2': line2,
        'city': city,
        'country': country,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (postalCode != null && postalCode!.isNotEmpty)
          'postalCode': postalCode,
      };

  @override
  List<Object?> get props =>
      [name, line1, line2, city, country, phone, postalCode];
}

/// Result of `POST /products/checkout/preview`.
class CheckoutPreviewEntity extends Equatable {
  const CheckoutPreviewEntity({
    required this.lines,
    required this.subtotalCoins,
    required this.commissionCoins,
    required this.totalCoins,
    required this.giftValueCoins,
    required this.coinDueCoins,
    required this.commissionPercent,
    required this.sellerId,
  });

  final List<CheckoutLineEntity> lines;
  final int subtotalCoins;
  final int commissionCoins;
  final int totalCoins;
  final int giftValueCoins;
  final int coinDueCoins;
  final int commissionPercent;
  final String sellerId;

  @override
  List<Object?> get props => [
        lines,
        subtotalCoins,
        commissionCoins,
        totalCoins,
        giftValueCoins,
        coinDueCoins,
        commissionPercent,
        sellerId,
      ];
}
