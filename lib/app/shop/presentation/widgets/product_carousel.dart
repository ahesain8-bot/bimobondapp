import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_card.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ProductCarousel extends StatelessWidget {
  const ProductCarousel({
    required this.title,
    required this.products,
    required this.onProductTap,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final List<ProductEntity> products;
  final void Function(ProductEntity product) onProductTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
                  ),
                  child: Text(
                    l10n.shopSeeAll,
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: ProductCard.gridCardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ProductCard.gridHorizontalPadding,
            ),
            itemCount: products.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: ProductCard.gridCrossAxisSpacing),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: ProductCard.gridCardWidth(context),
                child: ProductCard(
                  product: product,
                  onTap: () => onProductTap(product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
