import 'package:bimobondapp/app/shop/presentation/widgets/product_price.dart';
import 'package:flutter/material.dart';

class PriceDisplay extends StatelessWidget {
  const PriceDisplay({
    required this.priceCoins,
    this.compareAtCoins,
    this.size = PriceDisplaySize.medium,
    this.color,
    super.key,
  });

  final int priceCoins;
  final int? compareAtCoins;
  final PriceDisplaySize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fontSize = switch (size) {
      PriceDisplaySize.compact => 12.0,
      PriceDisplaySize.small => 14.0,
      PriceDisplaySize.medium => 18.0,
      PriceDisplaySize.large => 24.0,
    };

    return ProductPrice(
      priceCoins: priceCoins,
      compareAtCoins: compareAtCoins,
      fontSize: fontSize,
      iconSize: switch (size) {
        PriceDisplaySize.compact => 10,
        PriceDisplaySize.small => 12,
        _ => 14,
      },
    );
  }
}

enum PriceDisplaySize { compact, small, medium, large }
