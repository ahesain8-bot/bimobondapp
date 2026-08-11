import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_card.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

/// Shared pulsing block used by shop skeleton loaders.
class ShopSkeletonBox extends StatefulWidget {
  const ShopSkeletonBox({
    this.width,
    this.height,
    this.borderRadius,
    super.key,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<ShopSkeletonBox> createState() => _ShopSkeletonBoxState();
}

class _ShopSkeletonBoxState extends State<ShopSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(
          theme.shimmerBase,
          theme.shimmerHighlight,
          _controller.value,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                widget.borderRadius ??
                BorderRadius.circular(theme.cardRadius * 0.5),
          ),
        );
      },
    );
  }
}

class ProductSkeletonCard extends StatelessWidget {
  const ProductSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Mirrors [ProductCard] spacing/typography so image + footer match.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ShopSkeletonBox(
            borderRadius: BorderRadius.circular(ProductCard.imageRadius),
          ),
        ),
        const SizedBox(height: AppSizes.p4),
        const ShopSkeletonBox(height: 10, width: 32),
        const SizedBox(height: 1),
        const ShopSkeletonBox(height: 9, width: double.infinity),
      ],
    );
  }
}

class ProductSkeletonGrid extends StatelessWidget {
  const ProductSkeletonGrid({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        0,
        AppSizes.p16,
        AppSizes.p24,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ProductCard.gridCrossAxisCount,
          mainAxisSpacing: ProductCard.gridMainAxisSpacing,
          crossAxisSpacing: ProductCard.gridCrossAxisSpacing,
          childAspectRatio: ProductCard.gridChildAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => const ProductSkeletonCard(),
          childCount: itemCount,
        ),
      ),
    );
  }
}

/// Category circles + horizontal product rows for the shop home "All" state.
class ShopHomeSkeleton extends StatelessWidget {
  const ShopHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: CategoryStripSkeleton()),
        SliverToBoxAdapter(child: SizedBox(height: AppSizes.p8)),
        SliverToBoxAdapter(child: ProductCarouselSkeleton()),
        SliverToBoxAdapter(child: SizedBox(height: AppSizes.p12)),
        SliverToBoxAdapter(child: ProductCarouselSkeleton()),
        SliverToBoxAdapter(child: SizedBox(height: AppSizes.p16)),
        ProductSkeletonGrid(itemCount: 9),
        SliverToBoxAdapter(child: SizedBox(height: AppSizes.p24)),
      ],
    );
  }
}

class CategoryStripSkeleton extends StatelessWidget {
  const CategoryStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p16,
          AppSizes.p8,
          AppSizes.p8,
          AppSizes.p4,
        ),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.p16),
        itemBuilder: (_, _) => const SizedBox(
          width: 72,
          child: Column(
            children: [
              ShopSkeletonBox(
                width: 56,
                height: 56,
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              SizedBox(height: AppSizes.p8),
              ShopSkeletonBox(height: 10, width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductCarouselSkeleton extends StatelessWidget {
  const ProductCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p16,
            AppSizes.p16,
            AppSizes.p12,
          ),
          child: ShopSkeletonBox(
            height: 17,
            width: 120,
            borderRadius: BorderRadius.circular(theme.chipRadius),
          ),
        ),
        SizedBox(
          height: ProductCard.gridCardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ProductCard.gridHorizontalPadding,
            ),
            itemCount: 4,
            separatorBuilder: (_, _) =>
                const SizedBox(width: ProductCard.gridCrossAxisSpacing),
            itemBuilder: (_, _) => SizedBox(
              width: ProductCard.gridCardWidth(context),
              child: const ProductSkeletonCard(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Non-sliver grid for search / nested scroll views.
class ProductSkeletonGridView extends StatelessWidget {
  const ProductSkeletonGridView({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p8,
        AppSizes.p16,
        AppSizes.p24,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ProductCard.gridCrossAxisCount,
        mainAxisSpacing: ProductCard.gridMainAxisSpacing,
        crossAxisSpacing: ProductCard.gridCrossAxisSpacing,
        childAspectRatio: ProductCard.gridChildAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => const ProductSkeletonCard(),
    );
  }
}

class ProductDetailsSkeleton extends StatelessWidget {
  const ProductDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopSkeletonBox(
            height: 320,
            width: double.infinity,
            borderRadius: BorderRadius.zero,
          ),
          const SizedBox(height: AppSizes.p12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShopSkeletonBox(
                width: 8,
                height: 8,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 6),
              ShopSkeletonBox(
                width: 8,
                height: 8,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 6),
              ShopSkeletonBox(
                width: 8,
                height: 8,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopSkeletonBox(
                  height: 24,
                  width: 220,
                  borderRadius: BorderRadius.circular(theme.chipRadius),
                ),
                const SizedBox(height: AppSizes.p12),
                const ShopSkeletonBox(height: 14, width: 120),
                const SizedBox(height: AppSizes.p16),
                const ShopSkeletonBox(height: 12, width: double.infinity),
                const SizedBox(height: AppSizes.p8),
                const ShopSkeletonBox(height: 12, width: double.infinity),
                const SizedBox(height: AppSizes.p8),
                const ShopSkeletonBox(height: 12, width: 180),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartSkeleton extends StatelessWidget {
  const CartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.p16),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSizes.p12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(theme.cardRadius),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            ShopSkeletonBox(
              width: 72,
              height: 72,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(width: AppSizes.p12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShopSkeletonBox(height: 14, width: double.infinity),
                  SizedBox(height: AppSizes.p8),
                  ShopSkeletonBox(height: 12, width: 80),
                  SizedBox(height: AppSizes.p8),
                  ShopSkeletonBox(height: 12, width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersSkeleton extends StatelessWidget {
  const OrdersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.p16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSizes.p16),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: theme.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: ShopSkeletonBox(height: 14, width: 120)),
                ShopSkeletonBox(height: 20, width: 64),
              ],
            ),
            SizedBox(height: AppSizes.p12),
            ShopSkeletonBox(height: 12, width: 100),
            SizedBox(height: AppSizes.p8),
            ShopSkeletonBox(height: 14, width: 72),
          ],
        ),
      ),
    );
  }
}

class CheckoutSkeleton extends StatelessWidget {
  const CheckoutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p20,
        0,
        AppSizes.p20,
        AppSizes.p24,
      ),
      children: const [
        ShopSkeletonBox(height: 22, width: 160),
        SizedBox(height: AppSizes.p16),
        ShopSkeletonBox(height: 160, width: double.infinity),
      ],
    );
  }
}
