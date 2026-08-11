import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_bloc.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_event.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_state.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/orders_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/product_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/shop_search_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/category_chip.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_carousel.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_grid.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_header.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EcommerceHomeScreen extends StatelessWidget {
  const EcommerceHomeScreen({super.key});

  static const routeName = 'shop_home';

  static ShopBloc _createBloc() {
    return ShopBloc(
      getPlatformShopUseCase: shop_di.sl(),
      getProductCategoriesUseCase: shop_di.sl(),
      getCartUseCase: shop_di.sl(),
      addCartItemUseCase: shop_di.sl(),
      getProductUseCase: shop_di.sl(),
      previewCheckoutUseCase: shop_di.sl(),
      checkoutUseCase: shop_di.sl(),
      getMyOrdersUseCase: shop_di.sl(),
      getOrderUseCase: shop_di.sl(),
    )..add(const ShopStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _createBloc(),
      child: const ShopThemeScope(child: _EcommerceHomeView()),
    );
  }
}

class _EcommerceHomeView extends StatelessWidget {
  const _EcommerceHomeView();

  void _openProduct(BuildContext context, ProductEntity product) {
    context.pushNamed(
      ProductDetailsScreen.routeName,
      pathParameters: {'productId': product.id},
    );
  }

  String _categoryTitle(
    ShopState state,
    String? categoryId,
    AppLocalizations l10n,
  ) {
    if (categoryId == null || categoryId.isEmpty) return l10n.shopProducts;
    for (final category in state.categories) {
      if (category.id == categoryId) return category.name;
    }
    return l10n.shopProducts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedCategoryId = context.select(
      (ShopBloc b) => b.state.selectedCategoryId,
    );

    return Scaffold(
      backgroundColor: theme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ShopHeader(
          onSearchTap: () => context.pushNamed(ShopSearchScreen.routeName),
          onOrdersTap: () => context.pushNamed(OrdersScreen.routeName),
        ),
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listenWhen: (prev, curr) =>
            prev.error != curr.error && curr.error != null,
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          final selectedName = selectedCategoryId == null
              ? null
              : _categoryTitle(state, selectedCategoryId, l10n);
          final hasContent = state.products.isNotEmpty ||
              state.productsByCategory.values.any((list) => list.isNotEmpty);

          // One full-page skeleton for the whole first load — do not swap to a
          // second loader when categories arrive before products.
          if (state.loading && !hasContent && state.error == null) {
            return const ShopHomeSkeleton();
          }

          return RefreshIndicator(
            color: theme.primary,
            backgroundColor: theme.surface,
            onRefresh: () async {
              context.read<ShopBloc>().add(const ShopRefreshed());
              await context.read<ShopBloc>().stream.firstWhere(
                (s) => !s.refreshing,
              );
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _CategoryStrip(state: state, l10n: l10n),
                ),
                if (state.loading && !hasContent) ...[
                  if (selectedCategoryId != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.p16,
                          AppSizes.p12,
                          AppSizes.p16,
                          AppSizes.p12,
                        ),
                        child: Text(
                          selectedName ?? l10n.shopProducts,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                    const ProductSkeletonGrid(itemCount: 9),
                  ] else ...[
                    const SliverToBoxAdapter(child: ProductCarouselSkeleton()),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSizes.p12)),
                    const SliverToBoxAdapter(child: ProductCarouselSkeleton()),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSizes.p12)),
                    const SliverToBoxAdapter(child: ProductCarouselSkeleton()),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSizes.p16)),
                    const ProductSkeletonGrid(itemCount: 9),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSizes.p24)),
                  ],
                ] else if (state.error != null && state.products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(message: state.error!),
                  )
                else if (selectedCategoryId != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.p16,
                        AppSizes.p12,
                        AppSizes.p16,
                        AppSizes.p12,
                      ),
                      child: Text(
                        selectedName ?? l10n.shopProducts,
                        style: TextStyle(
                          color: theme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  ProductGrid(
                    products: state.products,
                    loading: state.loading,
                    loadingMore: state.loadingMore,
                    hasMore: state.hasMore,
                    onLoadMore: () =>
                        context.read<ShopBloc>().add(const ShopLoadMore()),
                    onProductTap: (product) => _openProduct(context, product),
                  ),
                ] else ...[
                  // All: one horizontal list per category.
                  ...state.categories.map((category) {
                    final items =
                        state.productsByCategory[category.id] ?? const [];
                    if (items.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverToBoxAdapter(
                      child: ProductCarousel(
                        title: category.name,
                        products: items,
                        onProductTap: (p) => _openProduct(context, p),
                        onSeeAll: () => context.read<ShopBloc>().add(
                          ShopCategorySelected(category.id),
                        ),
                      ),
                    );
                  }),
                  if (state.products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          l10n.shopNoProductsYet,
                          style: TextStyle(color: theme.mutedText),
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSizes.p24),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.state, required this.l10n});

  final ShopState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (state.categories.isEmpty && state.loading) {
      return const CategoryStripSkeleton();
    }

    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p16,
          AppSizes.p8,
          AppSizes.p8,
          AppSizes.p4,
        ),
        children: [
          CategoryChip(
            label: l10n.shopAllCategories,
            icon: LucideIcons.layoutGrid,
            selected: state.selectedCategoryId == null,
            onTap: () =>
                context.read<ShopBloc>().add(const ShopCategorySelected(null)),
          ),
          ...state.categories.map(
            (category) => CategoryChip(
              label: category.name,
              iconUrl: category.iconUrl,
              selected: state.selectedCategoryId == category.id,
              onTap: () => context.read<ShopBloc>().add(
                ShopCategorySelected(category.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

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
            Icon(Icons.error_outline, size: 48, color: theme.mutedText),
            const SizedBox(height: AppSizes.p16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.mutedText, fontSize: 14),
            ),
            const SizedBox(height: AppSizes.p16),
            FilledButton(
              onPressed: () =>
                  context.read<ShopBloc>().add(const ShopStarted()),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.buttonRadius),
                ),
              ),
              child: Text(l10n.shopRetry),
            ),
          ],
        ),
      ),
    );
  }
}
