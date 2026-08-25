import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_product_card.dart';
import 'package:bimobondapp/app/shop/data/datasources/shop_favorites_local_store.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart' as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/product_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LikedProductsScreen extends StatefulWidget {
  const LikedProductsScreen({super.key});

  static const routeName = 'marketplace_liked_products';

  @override
  State<LikedProductsScreen> createState() => _LikedProductsScreenState();
}

class _LikedProductsScreenState extends State<LikedProductsScreen> {
  final _favorites = shop_di.sl<ShopFavoritesLocalStore>();
  final _getProduct = shop_di.sl<GetProductUseCase>();

  List<ProductEntity> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final ids = _favorites.ids.toList();
    final products = <ProductEntity>[];

    for (final id in ids) {
      final result = await _getProduct(id);
      result.fold((_) {}, products.add);
    }

    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _openProduct(ProductEntity product) async {
    await context.pushNamed(
      ProductDetailsScreen.routeName,
      pathParameters: {'productId': product.id},
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = MarketplaceTheme.of(context);

    return MarketplaceThemeScope(
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: CustomAppBar(
          title: l10n.marketplaceLikedProducts,
          showBackButton: true,
          backgroundColor: theme.background,
        ),
        body: _loading
            ? const ProductSkeletonGrid()
            : _products.isEmpty
                ? Center(child: Text(l10n.marketplaceNoLikedProducts))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(
                        MarketplaceProductCardMetrics.gridPadding,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MarketplaceProductCardMetrics.gridCrossAxisCount(
                          context,
                        ),
                        mainAxisSpacing:
                            MarketplaceProductCardMetrics.gridSpacing,
                        crossAxisSpacing:
                            MarketplaceProductCardMetrics.gridSpacing,
                        childAspectRatio:
                            MarketplaceProductCardMetrics.gridChildAspectRatio(
                          context,
                        ),
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return MarketplaceProductCard(
                          product: product,
                          layout: MarketplaceProductCardLayout.grid,
                          onTap: () => _openProduct(product),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
