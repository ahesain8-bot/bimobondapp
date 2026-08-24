import 'package:bimobondapp/app/marketplace/domain/entities/marketplace_filters.dart';
import 'package:bimobondapp/app/marketplace/domain/utils/marketplace_category_config.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_filter_sheets.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_product_card.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/common_search_bar.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart' as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/product_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    required this.categoryId,
    required this.categorySlug,
    required this.categoryName,
    super.key,
  });

  static const routeName = 'marketplace_category';

  final String categoryId;
  final String categorySlug;
  final String categoryName;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final BrowseProductsUseCase _browse = shop_di.sl();
  final TextEditingController _searchController = TextEditingController();

  MarketplaceFilters _filters = MarketplaceFilters.empty;
  MarketplaceSortOption _sort = MarketplaceSortOption.popular;
  String _selectedBrand = 'All';

  List<ProductEntity> _products = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  bool get _showBrandFilters =>
      widget.categorySlug.toLowerCase() == 'phones';

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ({String sortBy, String sortOrder}) _sortParams() {
    return switch (_sort) {
      MarketplaceSortOption.popular => (sortBy: 'sortOrder', sortOrder: 'asc'),
      MarketplaceSortOption.newest => (sortBy: 'createdAt', sortOrder: 'desc'),
      MarketplaceSortOption.priceLowHigh => (sortBy: 'priceCoins', sortOrder: 'asc'),
      MarketplaceSortOption.priceHighLow => (sortBy: 'priceCoins', sortOrder: 'desc'),
      MarketplaceSortOption.endingSoon => (sortBy: 'sortOrder', sortOrder: 'asc'),
    };
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    final sort = _sortParams();
    final categoryId =
        widget.categoryId == 'all' ? null : widget.categoryId;

    final result = await _browse(
      BrowseProductsParams(
        page: refresh ? 1 : _page + 1,
        limit: 20,
        productCategoryId: categoryId,
        search: _filters.search ??
            (_searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim()),
        sortBy: sort.sortBy,
        sortOrder: sort.sortOrder,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ErrorMessageResolver.resolve(failure);
      }),
      (page) {
        var items = page.items;
        if (_filters.inStockOnly) {
          items = items.where((p) => p.inStock).toList();
        }
        if (_selectedBrand != 'All') {
          items = items
              .where(
                (p) => p.title.toLowerCase().contains(
                      _selectedBrand.toLowerCase(),
                    ),
              )
              .toList();
        }

        setState(() {
          _loading = false;
          _loadingMore = false;
          _page = page.page;
          _hasMore = page.hasMore;
          _products = refresh ? items : [..._products, ...items];
        });
      },
    );
  }

  Future<void> _openFilters() async {
    final next = await showMarketplaceFilterSheet(
      context: context,
      initial: _filters,
    );
    if (next == null) return;
    setState(() => _filters = next);
    await _load(refresh: true);
  }

  Future<void> _openSort() async {
    final next = await showMarketplaceSortSheet(
      context: context,
      initial: _sort,
    );
    if (next == null) return;
    setState(() => _sort = next);
    await _load(refresh: true);
  }

  void _openProduct(ProductEntity product) {
    context.pushNamed(
      ProductDetailsScreen.routeName,
      pathParameters: {'productId': product.id},
    );
  }

  String _sortLabel(AppLocalizations l10n) {
    return switch (_sort) {
      MarketplaceSortOption.popular => l10n.marketplaceSortPopular,
      MarketplaceSortOption.newest => l10n.shopSortNewest,
      MarketplaceSortOption.priceLowHigh => l10n.shopSortPriceLow,
      MarketplaceSortOption.priceHighLow => l10n.shopSortPriceHigh,
      MarketplaceSortOption.endingSoon => l10n.marketplaceSortEndingSoon,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MarketplaceThemeScope(
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: const ShopBackButton(),
          title: Text(
            widget.categoryName,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _openFilters,
              icon: Icon(LucideIcons.slidersHorizontal, color: theme.onSurface),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p4,
                AppSizes.p16,
                AppSizes.p8,
              ),
              child: CommonSearchBar(
                controller: _searchController,
                hintText: l10n.marketplaceSearchHint,
                onSubmitted: () => _load(refresh: true),
                onChanged: (_) {},
              ),
            ),
            if (_showBrandFilters)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: kPhoneBrands.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final brand = kPhoneBrands[index];
                    final selected = _selectedBrand == brand;
                    return FilterChip(
                      label: Text(brand),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedBrand = brand);
                        _load(refresh: true);
                      },
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    l10n.marketplaceProductCount(_products.length),
                    style: TextStyle(color: theme.mutedText, fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openSort,
                    icon: Icon(LucideIcons.arrowUpDown, size: 16, color: theme.primary),
                    label: Text(
                      '${l10n.shopSort}: ${_sortLabel(l10n)}',
                      style: TextStyle(color: theme.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const ProductSkeletonGrid()
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!),
                              FilledButton(
                                onPressed: () => _load(refresh: true),
                                child: Text(l10n.shopRetry),
                              ),
                            ],
                          ),
                        )
                      : _products.isEmpty
                          ? Center(child: Text(l10n.shopEmpty))
                          : RefreshIndicator(
                              onRefresh: () => _load(refresh: true),
                              child: GridView.builder(
                                padding: const EdgeInsets.all(
                                  MarketplaceProductCardMetrics.gridPadding,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
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
                                itemCount:
                                    _products.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _products.length) {
                                    _load();
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final product = _products[index];
                                  return MarketplaceProductCard(
                                    product: product,
                                    layout: MarketplaceProductCardLayout.grid,
                                    onTap: () => _openProduct(product),
                                    onBuyNow: () => _openProduct(product),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
