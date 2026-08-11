import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_card.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    required this.products,
    required this.onProductTap,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.onLoadMore,
    super.key,
  });

  final List<ProductEntity> products;
  final void Function(ProductEntity product) onProductTap;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const ProductSkeletonGrid();
    }

    if (products.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyProducts(),
      );
    }

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
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= products.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.p16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final product = products[index];
          final isLast = index == products.length - 1;

          if (isLast && hasMore && !loadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onLoadMore?.call();
            });
          }

          return ProductCard(
            product: product,
            onTap: () => onProductTap(product),
          );
        }, childCount: products.length + (loadingMore ? 1 : 0)),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 48, color: theme.mutedText),
            const SizedBox(height: AppSizes.p16),
            Text(
              l10n.shopEmpty,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              l10n.shopEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.mutedText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
