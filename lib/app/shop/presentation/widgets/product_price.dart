import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProductPrice extends StatelessWidget {
  const ProductPrice({
    required this.priceCoins,
    this.compareAtCoins,
    this.iconSize = 14,
    this.fontSize = 14,
    this.showCompareAt = true,
    this.vertical = false,
    this.compareAbove = false,
    super.key,
  });

  final int priceCoins;
  final int? compareAtCoins;
  final double iconSize;
  final double fontSize;
  final bool showCompareAt;
  final bool vertical;
  /// When true, strikethrough compare sits above the sale price (detail bar).
  final bool compareAbove;

  String _format(int coins) => coins.toString();

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final hasCompare =
        showCompareAt && compareAtCoins != null && compareAtCoins! > priceCoins;

    final priceRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (iconSize > 0) ...[
          Icon(
            LucideIcons.coins,
            size: iconSize,
            color: theme.primary,
          ),
          const SizedBox(width: AppSizes.p4),
        ],
        Text(
          _format(priceCoins),
          style: TextStyle(
            color: theme.priceText,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        if (hasCompare && !compareAbove) ...[
          const SizedBox(width: AppSizes.p6),
          Text(
            _format(compareAtCoins!),
            style: TextStyle(
              color: theme.compareAtText,
              fontSize: fontSize - 2,
              decoration: TextDecoration.lineThrough,
              decorationColor: theme.compareAtText,
              height: 1.1,
            ),
          ),
        ],
      ],
    );

    if (!hasCompare || !compareAbove) {
      if (vertical) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [priceRow],
        );
      }
      return priceRow;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _format(compareAtCoins!),
          style: TextStyle(
            color: theme.compareAtText,
            fontSize: fontSize * 0.55,
            decoration: TextDecoration.lineThrough,
            decorationColor: theme.compareAtText,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        priceRow,
      ],
    );
  }
}
