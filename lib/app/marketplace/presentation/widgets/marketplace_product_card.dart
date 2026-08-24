import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/price_display.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/wishlist_button.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

enum MarketplaceProductCardLayout { horizontal, grid, list }

/// Shared sizing so carousels, grids, and skeletons stay aligned.
abstract final class MarketplaceProductCardMetrics {
  static const double horizontalListPadding = 16;
  static const double horizontalGap = 8;
  static const double cardPadding = 8;
  static const double gridPadding = 12;
  static const double gridSpacing = 8;

  static double horizontalCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final available = screenWidth - horizontalListPadding * 2 - horizontalGap * 2;
    return (available / 2.35).clamp(120.0, 158.0);
  }

  static double horizontalCarouselHeight(BuildContext context) {
    final cardWidth = horizontalCardWidth(context);
    final imageSize = cardWidth - cardPadding * 2;
    const titleHeight = 13.0;
    const priceHeight = 14.0;
    const verticalGaps = 6.0 + 4.0;

    return cardPadding * 2 +
        imageSize +
        verticalGaps +
        titleHeight +
        priceHeight;
  }

  static int gridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  static double gridChildAspectRatio(BuildContext context) {
    final columns = gridCrossAxisCount(context);
    if (columns >= 4) return 0.82;
    if (columns >= 3) return 0.8;
    return 0.78;
  }
}

class MarketplaceProductCard extends StatelessWidget {
  const MarketplaceProductCard({
    required this.product,
    required this.onTap,
    this.onBuyNow,
    this.layout = MarketplaceProductCardLayout.horizontal,
    super.key,
  });

  final ProductEntity product;
  final VoidCallback onTap;
  final VoidCallback? onBuyNow;
  final MarketplaceProductCardLayout layout;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      MarketplaceProductCardLayout.horizontal => _HorizontalCard(
          product: product,
          onTap: onTap,
        ),
      MarketplaceProductCardLayout.grid => _GridCard(
          product: product,
          onTap: onTap,
        ),
      MarketplaceProductCardLayout.list => _ListCard(
          product: product,
          onTap: onTap,
          onBuyNow: onBuyNow,
        ),
    };
  }
}

class _HorizontalCard extends StatelessWidget {
  const _HorizontalCard({
    required this.product,
    required this.onTap,
  });

  final ProductEntity product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final width = MarketplaceProductCardMetrics.horizontalCardWidth(context);

    return SizedBox(
      width: width,
      child: Material(
        color: theme.card,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: theme.productCardDecoration(radius: MarketplaceTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.all(MarketplaceProductCardMetrics.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(MarketplaceTheme.radiusXs),
                          child: SafeNetworkImage(
                            imageUrl: product.displayImageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: WishlistButton(
                            productId: product.id,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PriceDisplay(
                    priceCoins: product.priceCoins,
                    compareAtCoins: product.compareAtCoins,
                    size: PriceDisplaySize.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.product,
    required this.onTap,
  });

  final ProductEntity product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);

    return Material(
      color: theme.card,
      borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: theme.productCardDecoration(radius: MarketplaceTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.all(MarketplaceProductCardMetrics.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(MarketplaceTheme.radiusXs),
                        child: SafeNetworkImage(
                          imageUrl: product.displayImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: WishlistButton(productId: product.id, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                PriceDisplay(
                  priceCoins: product.priceCoins,
                  compareAtCoins: product.compareAtCoins,
                  size: PriceDisplaySize.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.product,
    required this.onTap,
    this.onBuyNow,
  });

  final ProductEntity product;
  final VoidCallback onTap;
  final VoidCallback? onBuyNow;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);

    return Material(
      color: theme.card,
      borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: theme.productCardDecoration(radius: MarketplaceTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(MarketplaceTheme.radiusXs),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: SafeNetworkImage(
                      imageUrl: product.displayImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PriceDisplay(
                        priceCoins: product.priceCoins,
                        compareAtCoins: product.compareAtCoins,
                        size: PriceDisplaySize.compact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: onBuyNow ?? onTap,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.shop.onAccent,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
