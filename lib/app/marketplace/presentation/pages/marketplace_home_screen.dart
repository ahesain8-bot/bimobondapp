import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/marketplace/domain/utils/marketplace_category_config.dart';
import 'package:bimobondapp/app/marketplace/presentation/bloc/marketplace_home_bloc.dart';
import 'package:bimobondapp/app/marketplace/presentation/bloc/marketplace_home_state.dart';
import 'package:bimobondapp/app/marketplace/presentation/pages/category_products_screen.dart';
import 'package:bimobondapp/app/marketplace/presentation/pages/marketplace_auction_details_screen.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/category_card.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_auction_card.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_header.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_hero_banner.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_home_skeleton.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_product_card.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/cart_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/product_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/shop_search_screen.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/common_search_bar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MarketplaceHomeScreen extends StatelessWidget {
  const MarketplaceHomeScreen({super.key});

  static const routeName = 'marketplace_home';

  static MarketplaceHomeBloc _createBloc() {
    return MarketplaceHomeBloc(
      getProductCategoriesUseCase: shop_di.sl(),
      getPlatformShopUseCase: shop_di.sl(),
      getActiveAuctionsUseCase: auctions_di.sl(),
    )..add(MarketplaceHomeStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _createBloc(),
      child: const MarketplaceThemeScope(child: _MarketplaceHomeView()),
    );
  }
}

class _MarketplaceHomeView extends StatelessWidget {
  const _MarketplaceHomeView();

  void _openProduct(BuildContext context, ProductEntity product) {
    context.pushNamed(
      ProductDetailsScreen.routeName,
      pathParameters: {'productId': product.id},
    );
  }

  void _openCategory(BuildContext context, ProductCategoryEntity? category) {
    context.pushNamed(
      CategoryProductsScreen.routeName,
      pathParameters: {'categoryId': category?.id ?? 'all'},
      queryParameters: {
        'slug': category?.slug ?? 'all',
        'name': category?.name ?? 'All',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = MarketplaceTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: MarketplaceHeader(
        onCartTap: () => context.pushNamed(CartScreen.routeName),
      ),
      body: BlocBuilder<MarketplaceHomeBloc, MarketplaceHomeState>(
        builder: (context, state) {
          if (state.loading && state.recommended.isEmpty) {
            return const MarketplaceHomeSkeleton();
          }

          if (state.error != null && state.recommended.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.read<MarketplaceHomeBloc>().add(
                      MarketplaceHomeStarted(),
                    ),
                    child: Text(l10n.shopRetry),
                  ),
                ],
              ),
            );
          }

          final apiCategories = state.categories;
          final displayCategories = apiCategories.isNotEmpty
              ? apiCategories
              : kMarketplaceCategories
                    .map(
                      (c) => ProductCategoryEntity(
                        id: c.slug,
                        name: c.fallbackName,
                        slug: c.slug,
                      ),
                    )
                    .toList();

          return RefreshIndicator(
            onRefresh: () async {
              context.read<MarketplaceHomeBloc>().add(
                MarketplaceHomeRefreshed(),
              );
              await context.read<MarketplaceHomeBloc>().stream.firstWhere(
                (s) => !s.refreshing,
              );
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.p16,
                      AppSizes.p4,
                      AppSizes.p16,
                      AppSizes.p8,
                    ),
                    child: CommonSearchBar(
                      readOnly: true,
                      hintText: l10n.marketplaceSearchHint,
                      fillColor: theme.surface,
                      textColor: theme.onSurface,
                      hintColor: theme.mutedText,
                      iconColor: theme.mutedText,
                      onTap: () =>
                          context.pushNamed(ShopSearchScreen.routeName),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MarketplaceHeroBanner(
                    onExplore: () => _openCategory(context, null),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MarketplaceSectionHeader(
                    title: l10n.marketplaceCategories,
                    actionLabel: l10n.shopSeeAll,
                    onAction: () => _openCategory(context, null),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 0,
                          crossAxisSpacing: 0,
                          childAspectRatio: 1.0,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= displayCategories.length) return null;
                      final cat = displayCategories[index];
                      final config = categoryConfigForEntity(cat);
                      return CategoryCard(
                        config: config,
                        label: cat.name,
                        iconUrl: cat.iconUrl,
                        onTap: () => _openCategory(context, cat),
                      );
                    }, childCount: displayCategories.length.clamp(0, 12)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MarketplaceSectionHeader(
                    title: l10n.marketplaceRecommended,
                    actionLabel: l10n.shopSeeAll,
                    onAction: () => _openCategory(context, null),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MarketplaceProductCardMetrics.horizontalCarouselHeight(
                          context,
                        ),
                    child: state.recommended.isEmpty
                        ? Center(child: Text(l10n.shopEmpty))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MarketplaceProductCardMetrics
                                  .horizontalListPadding,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: state.recommended.length,
                            separatorBuilder: (_, __) => const SizedBox(
                              width:
                                  MarketplaceProductCardMetrics.horizontalGap,
                            ),
                            itemBuilder: (context, index) {
                              final product = state.recommended[index];
                              return MarketplaceProductCard(
                                product: product,
                                onTap: () => _openProduct(context, product),
                                onBuyNow: () => _openProduct(context, product),
                              );
                            },
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MarketplaceSectionHeader(
                    title: l10n.marketplaceEndingSoon,
                    actionLabel: l10n.shopSeeAll,
                    onAction: () => context.go('/?tab=1'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: state.endingSoonAuctions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.marketplaceNoAuctions),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: MarketplaceProductCardMetrics
                                .horizontalListPadding,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < state.endingSoonAuctions.length;
                                index++
                              ) ...[
                                if (index > 0)
                                  const SizedBox(
                                    width: MarketplaceProductCardMetrics
                                        .horizontalGap,
                                  ),
                                MarketplaceAuctionCard(
                                  auction: state.endingSoonAuctions[index],
                                  onTap: () => context.pushNamed(
                                    MarketplaceAuctionDetailsScreen.routeName,
                                    pathParameters: {
                                      'auctionId':
                                          state.endingSoonAuctions[index].id,
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}
