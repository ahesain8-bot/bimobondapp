import 'package:bimobondapp/app/shop/presentation/bloc/shop_bloc.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_event.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_state.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/product_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_card.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ShopSearchScreen extends StatefulWidget {
  const ShopSearchScreen({super.key});

  static const routeName = 'shop_search';

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
    );
  }

  @override
  State<ShopSearchScreen> createState() => _ShopSearchScreenState();
}

class _ShopSearchScreenState extends State<ShopSearchScreen> {
  late final ShopBloc _bloc;
  late final TextEditingController _controller;
  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _bloc = ShopSearchScreen._createBloc();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _bloc.close();
    super.dispose();
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (!_recentSearches.contains(trimmed)) {
      setState(() {
        _recentSearches.insert(0, trimmed);
        if (_recentSearches.length > 8) {
          _recentSearches.removeLast();
        }
      });
    }

    _bloc.add(ShopSearchChanged(trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider.value(
      value: _bloc,
      child: ShopThemeScope(
        child: Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.background,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: const ShopBackButton(),
            iconTheme: IconThemeData(color: theme.onSurface),
            title: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: theme.onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: l10n.shopSearchHint,
                hintStyle: TextStyle(color: theme.mutedText),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(LucideIcons.search, color: theme.onSurface),
                  onPressed: () => _submitSearch(_controller.text),
                ),
              ),
              onSubmitted: _submitSearch,
              onChanged: (value) => _bloc.add(ShopSearchChanged(value)),
            ),
            actions: [
              BlocBuilder<ShopBloc, ShopState>(
                builder: (context, state) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _SortChipButton(
                      label: _sortLabel(l10n, state.sortBy, state.sortOrder),
                      onTap: () => _openSortSheet(context, state),
                    ),
                  );
                },
              ),
            ],
          ),
          body: BlocBuilder<ShopBloc, ShopState>(
            builder: (context, state) {
              if (state.searchQuery.isEmpty) {
                return _RecentSearches(
                  recent: _recentSearches,
                  onTap: (query) {
                    _controller.text = query;
                    _submitSearch(query);
                  },
                  l10n: l10n,
                );
              }

              if (state.loading) {
                return const ProductSkeletonGridView();
              }

              if (state.products.isEmpty) {
                return Center(
                  child: Text(
                    l10n.shopNoResultsFor(state.searchQuery),
                    style: TextStyle(color: theme.mutedText),
                  ),
                );
              }

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
                itemCount: state.products.length,
                itemBuilder: (context, index) {
                  final product = state.products[index];
                  return ProductCard(
                    product: product,
                    onTap: () => context.pushNamed(
                      ProductDetailsScreen.routeName,
                      pathParameters: {'productId': product.id},
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _sortLabel(AppLocalizations l10n, String sortBy, String sortOrder) {
    return switch ('$sortBy:$sortOrder') {
      'createdAt:desc' => l10n.shopSortNewest,
      'createdAt:asc' => l10n.shopSortOldest,
      'priceCoins:asc' => l10n.shopSortPriceLow,
      'priceCoins:desc' => l10n.shopSortPriceHigh,
      'title:asc' => l10n.shopSortTitleAsc,
      'title:desc' => l10n.shopSortTitleDesc,
      _ => l10n.shopSortNewest,
    };
  }

  Future<void> _openSortSheet(BuildContext context, ShopState state) async {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final options = <({String label, String sortBy, String sortOrder})>[
      (
        label: l10n.shopSortNewest,
        sortBy: 'createdAt',
        sortOrder: 'desc',
      ),
      (
        label: l10n.shopSortOldest,
        sortBy: 'createdAt',
        sortOrder: 'asc',
      ),
      (
        label: l10n.shopSortPriceLow,
        sortBy: 'priceCoins',
        sortOrder: 'asc',
      ),
      (
        label: l10n.shopSortPriceHigh,
        sortBy: 'priceCoins',
        sortOrder: 'desc',
      ),
      (
        label: l10n.shopSortTitleAsc,
        sortBy: 'title',
        sortOrder: 'asc',
      ),
      (
        label: l10n.shopSortTitleDesc,
        sortBy: 'title',
        sortOrder: 'desc',
      ),
    ];

    final selected = await showModalBottomSheet<({String sortBy, String sortOrder})>(
      context: context,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.shopSort,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final option in options)
                  _SortOptionTile(
                    label: option.label,
                    selected: state.sortBy == option.sortBy &&
                        state.sortOrder == option.sortOrder,
                    onTap: () => Navigator.of(ctx).pop(
                      (sortBy: option.sortBy, sortOrder: option.sortOrder),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    _bloc.add(
      ShopSortChanged(sortBy: selected.sortBy, sortOrder: selected.sortOrder),
    );
  }
}

class _SortChipButton extends StatelessWidget {
  const _SortChipButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    return Material(
      color: theme.surface,
      borderRadius: BorderRadius.circular(theme.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.chipRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.chipRadius),
            border: Border.all(color: theme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.arrowUpDown, size: 14, color: theme.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 88),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: selected
            ? theme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    LucideIcons.check,
                    size: 18,
                    color: theme.primary,
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

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.recent,
    required this.onTap,
    required this.l10n,
  });

  final List<String> recent;
  final ValueChanged<String> onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    if (recent.isEmpty) {
      return Center(
        child: Text(
          l10n.shopSearchForProducts,
          style: TextStyle(color: theme.mutedText),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.p16),
      children: [
        Text(
          l10n.shopRecentSearches,
          style: TextStyle(color: theme.onSurface, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSizes.p12),
        ...recent.map(
          (query) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.clock, color: theme.mutedText, size: 18),
            title: Text(query, style: TextStyle(color: theme.onSurface)),
            onTap: () => onTap(query),
          ),
        ),
      ],
    );
  }
}
