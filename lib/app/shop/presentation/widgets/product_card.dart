import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/discount_badge.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_price.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, required this.onTap, super.key});

  final ProductEntity product;
  final VoidCallback onTap;

  /// Shared metrics so skeletons / carousels match category grids.
  static const double imageRadius = 8;
  static const double gridHorizontalPadding = AppSizes.p16;
  static const int gridCrossAxisCount = 4;
  static const double gridMainAxisSpacing = AppSizes.p6;
  static const double gridCrossAxisSpacing = AppSizes.p4;
  static const double gridChildAspectRatio = 0.72;

  /// Same card width as a category grid cell.
  static double gridCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final available = screenWidth - (gridHorizontalPadding * 2);
    return (available - gridCrossAxisSpacing * (gridCrossAxisCount - 1)) /
        gridCrossAxisCount;
  }

  /// Same card height as a category grid cell.
  static double gridCardHeight(BuildContext context) {
    return gridCardWidth(context) / gridChildAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final radius = BorderRadius.circular(imageRadius);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: radius,
                      border: Border.all(
                        color: theme.border.withValues(alpha: 0.7),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: SafeNetworkImage(
                        imageUrl: product.displayImageUrl,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  if (product.hasDiscount)
                    Positioned(
                      top: AppSizes.p4,
                      right: AppSizes.p4,
                      child: DiscountBadge(
                        percentage: product.discountPercentage,
                      ),
                    ),
                  if (product.isLive)
                    Positioned(
                      top: AppSizes.p4,
                      left: AppSizes.p4,
                      child: _MiniChip(
                        label: l10n.shopLiveBadge,
                        background: theme.onSurface,
                        foreground: theme.background,
                      ),
                    )
                  else if (product.hasDiscount &&
                      product.discountPercentage >= 15)
                    Positioned(
                      top: AppSizes.p4,
                      left: AppSizes.p4,
                      child: _MiniChip(
                        label: l10n.shopBestPrice,
                        background: theme.onSurface,
                        foreground: theme.background,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p4),
            ProductPrice(
              priceCoins: product.priceCoins,
              compareAtCoins: product.compareAtCoins,
              fontSize: 10,
              iconSize: 0,
            ),
            const SizedBox(height: 1),
            Text(
              product.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.mutedText,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                height: 1.1,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
