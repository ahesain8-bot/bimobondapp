import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({
    required this.percentage,
    super.key,
  });

  final int percentage;

  @override
  Widget build(BuildContext context) {
    if (percentage <= 0) return const SizedBox.shrink();

    final theme = ShopTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.discountBadgeBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          color: theme.discountBadgeText,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
