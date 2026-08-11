import 'package:bimobondapp/app/shop/data/datasources/shop_favorites_local_store.dart';
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_bloc.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_event.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_state.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/checkout_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_image_gallery.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_price.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({
    required this.productId,
    this.liveId,
    this.postId,
    super.key,
  });

  static const routeName = 'shop_product';

  final String productId;
  final String? liveId;
  final String? postId;

  static ShopBloc _createBloc(String productId) {
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
    )..add(ShopLoadProduct(productId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _createBloc(productId),
      child: ShopThemeScope(
        child: _ProductDetailsView(
          productId: productId,
          liveId: liveId,
          postId: postId,
        ),
      ),
    );
  }
}

class _ProductDetailsView extends StatefulWidget {
  const _ProductDetailsView({
    required this.productId,
    this.liveId,
    this.postId,
  });

  final String productId;
  final String? liveId;
  final String? postId;

  @override
  State<_ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends State<_ProductDetailsView> {
  int _quantity = 1;
  String? _selectedVariantId;
  late final ShopFavoritesLocalStore _favorites;
  bool _isFavorite = false;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _favorites = shop_di.sl<ShopFavoritesLocalStore>();
    _isFavorite = _favorites.isFavorite(widget.productId);
  }

  Future<void> _toggleFavorite() async {
    final next = await _favorites.toggle(widget.productId);
    if (!mounted) return;
    setState(() => _isFavorite = next);
  }

  Future<void> _share(ProductEntity product) async {
    await SharePlus.instance.share(
      ShareParams(text: product.title),
    );
  }

  int _effectivePrice(ProductEntity product) {
    if (_selectedVariantId == null) return product.priceCoins;
    final variant = product.variants.firstWhere(
      (v) => v.id == _selectedVariantId,
      orElse: () => product.variants.first,
    );
    return variant.priceCoins;
  }

  bool _ensureVariantSelected(ProductEntity product) {
    if (product.variants.isEmpty) return true;
    if (_selectedVariantId != null) return true;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.shopSelectVariantFirst)),
    );
    return false;
  }

  void _buyNow(ProductEntity product) {
    if (!_ensureVariantSelected(product)) return;
    final query = <String, String>{
      if (widget.liveId != null && widget.liveId!.isNotEmpty)
        'liveId': widget.liveId!,
      if (widget.postId != null && widget.postId!.isNotEmpty)
        'postId': widget.postId!,
    };
    context.pushNamed(
      CheckoutScreen.routeName,
      queryParameters: query,
      extra: {
        'items': [
          CheckoutItemInput(
            productId: product.id,
            variantId: _selectedVariantId,
            quantity: _quantity,
          ),
        ],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const ShopBackButton(),
        actions: [
          IconButton(
            tooltip: _isFavorite ? l10n.shopRemoveFavorite : l10n.shopAddFavorite,
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? theme.primary : theme.onSurface,
            ),
          ),
          IconButton(
            tooltip: l10n.shopShare,
            onPressed: () {
              final product = context.read<ShopBloc>().state.selectedProduct;
              if (product != null) _share(product);
            },
            icon: Icon(LucideIcons.share, color: theme.onSurface, size: 22),
          ),
        ],
      ),
      body: BlocListener<ShopBloc, ShopState>(
        listenWhen: (prev, next) =>
            prev.selectedProduct?.id != next.selectedProduct?.id ||
            prev.selectedProduct?.isFavorite !=
                next.selectedProduct?.isFavorite,
        listener: (context, state) {
          final product = state.selectedProduct;
          if (product != null) {
            final favorite =
                product.isFavorite || _favorites.isFavorite(product.id);
            if (favorite != _isFavorite) {
              setState(() => _isFavorite = favorite);
            }
          }
        },
        child: BlocBuilder<ShopBloc, ShopState>(
          builder: (context, state) {
            if (state.loadingProduct && state.selectedProduct == null) {
              return const ProductDetailsSkeleton();
            }

            if (state.selectedProduct == null) {
              return Center(
                child: Text(
                  state.error ?? l10n.shopProductNotFound,
                  style: TextStyle(color: theme.mutedText),
                ),
              );
            }

            final product = state.selectedProduct!;
            final price = _effectivePrice(product);
            final outOfStock = product.trackInventory &&
                (product.variants.isEmpty
                    ? product.stockQuantity <= 0
                    : product.variants.every((v) => v.stockQuantity <= 0));
            final description = product.description?.trim() ?? '';
            final canCollapse = description.length > 140;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProductImageGallery(
                          product: product,
                          heroTag: 'shop-product-${product.id}',
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.p16,
                            AppSizes.p20,
                            AppSizes.p16,
                            AppSizes.p24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.title,
                                style: TextStyle(
                                  color: theme.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                ),
                              ),
                              if (product.seller != null) ...[
                                const SizedBox(height: AppSizes.p10),
                                Text(
                                  product.seller!.username,
                                  style: TextStyle(
                                    color: theme.mutedText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: AppSizes.p16),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: canCollapse &&
                                                !_descriptionExpanded
                                            ? '${description.substring(0, 140).trimRight()}… '
                                            : '$description ',
                                        style: TextStyle(
                                          color: theme.onSurface
                                              .withValues(alpha: 0.75),
                                          fontSize: 14,
                                          height: 1.55,
                                        ),
                                      ),
                                      if (canCollapse)
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.baseline,
                                          baseline: TextBaseline.alphabetic,
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _descriptionExpanded =
                                                  !_descriptionExpanded,
                                            ),
                                            child: Text(
                                              _descriptionExpanded
                                                  ? l10n.shopShowLess
                                                  : l10n.shopReadMore,
                                              style: TextStyle(
                                                color: theme.primary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              if (product.variants.isNotEmpty) ...[
                                const SizedBox(height: AppSizes.p24),
                                Text(
                                  l10n.shopVariants,
                                  style: TextStyle(
                                    color: theme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.p10),
                                Wrap(
                                  spacing: AppSizes.p8,
                                  runSpacing: AppSizes.p8,
                                  children: product.variants.map((variant) {
                                    final selected =
                                        _selectedVariantId == variant.id;
                                    return ChoiceChip(
                                      label: Text(variant.name),
                                      selected: selected,
                                      selectedColor: theme.primary
                                          .withValues(alpha: 0.15),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? theme.primary
                                            : theme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      side: BorderSide(
                                        color: selected
                                            ? theme.primary
                                            : theme.border,
                                      ),
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedVariantId = variant.id;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: AppSizes.p20),
                              Text(
                                l10n.shopQuantity,
                                style: TextStyle(
                                  color: theme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSizes.p10),
                              _QuantityStepper(
                                quantity: _quantity,
                                onChanged: (q) =>
                                    setState(() => _quantity = q),
                              ),
                              if (outOfStock) ...[
                                const SizedBox(height: AppSizes.p12),
                                Text(
                                  l10n.shopOutOfStock,
                                  style: TextStyle(
                                    color: theme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomBar(
                  priceCoins: price,
                  compareAtCoins: product.compareAtCoins,
                  disabled: outOfStock,
                  buyLabel: l10n.shopBuyNow,
                  onBuyNow: () => _buyNow(product),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.buttonRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: Icon(LucideIcons.minus, color: theme.onSurface, size: 18),
          ),
          Text(
            '$quantity',
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: () => onChanged(quantity + 1),
            icon: Icon(LucideIcons.plus, color: theme.onSurface, size: 18),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.priceCoins,
    required this.compareAtCoins,
    required this.disabled,
    required this.buyLabel,
    required this.onBuyNow,
  });

  final int priceCoins;
  final int? compareAtCoins;
  final bool disabled;
  final String buyLabel;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p12,
        AppSizes.p16,
        AppSizes.p16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          ProductPrice(
            priceCoins: priceCoins,
            compareAtCoins: compareAtCoins,
            fontSize: 22,
            iconSize: 0,
            compareAbove: true,
          ),
          const SizedBox(width: AppSizes.p16),
          Expanded(
            child: FilledButton(
              onPressed: disabled ? null : onBuyNow,
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.onAccent,
                disabledBackgroundColor: theme.primary.withValues(alpha: 0.4),
                elevation: 0,
                minimumSize: const Size(0, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.buttonRadius),
                ),
              ),
              child: Text(
                buyLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
