import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_product_card.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

/// Loading placeholder aligned with [MarketplaceHomeScreen] layout.
class MarketplaceHomeSkeleton extends StatelessWidget {
  const MarketplaceHomeSkeleton({super.key});

  double _heroHeight(BuildContext context) =>
      MarketplaceTheme.heroCarouselHeight(context);

  @override
  Widget build(BuildContext context) {
    final heroHeight = _heroHeight(context);
    final productCarouselHeight =
        MarketplaceProductCardMetrics.horizontalCarouselHeight(context);
    final productCardWidth =
        MarketplaceProductCardMetrics.horizontalCardWidth(context);

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p4,
              AppSizes.p16,
              AppSizes.p8,
            ),
            child: ShopSkeletonBox(
              height: 48,
              width: double.infinity,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: heroHeight,
              child: ShopSkeletonBox(
                width: double.infinity,
                height: heroHeight,
                borderRadius:
                    BorderRadius.circular(MarketplaceTheme.radiusLg),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _MarketplaceSectionHeaderSkeleton()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, _) => const _CategoryGridItemSkeleton(),
              childCount: 10,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: _MarketplaceSectionHeaderSkeleton(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: productCarouselHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MarketplaceProductCardMetrics.horizontalListPadding,
              ),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(
                width: MarketplaceProductCardMetrics.horizontalGap,
              ),
              itemBuilder: (_, _) => SizedBox(
                width: productCardWidth,
                child: const _MarketplaceProductCardSkeleton(),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _MarketplaceSectionHeaderSkeleton extends StatelessWidget {
  const _MarketplaceSectionHeaderSkeleton({this.padding});

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          ShopSkeletonBox(
            height: 18,
            width: 120,
            borderRadius: BorderRadius.circular(8),
          ),
          const Spacer(),
          ShopSkeletonBox(
            height: 14,
            width: 52,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

class _CategoryGridItemSkeleton extends StatelessWidget {
  const _CategoryGridItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShopSkeletonBox(
          width: 56,
          height: 56,
          borderRadius: BorderRadius.all(Radius.circular(MarketplaceTheme.radiusMd)),
        ),
        SizedBox(height: 4),
        ShopSkeletonBox(height: 10, width: 40),
      ],
    );
  }
}

class _MarketplaceProductCardSkeleton extends StatelessWidget {
  const _MarketplaceProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: MarketplaceTheme.of(context).productCardDecoration(),
      child: const Padding(
        padding: EdgeInsets.all(MarketplaceProductCardMetrics.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ShopSkeletonBox(
                borderRadius: BorderRadius.all(
                  Radius.circular(MarketplaceTheme.radiusXs),
                ),
              ),
            ),
            SizedBox(height: 6),
            ShopSkeletonBox(height: 11, width: double.infinity),
            SizedBox(height: 4),
            ShopSkeletonBox(height: 12, width: 48),
          ],
        ),
      ),
    );
  }
}
