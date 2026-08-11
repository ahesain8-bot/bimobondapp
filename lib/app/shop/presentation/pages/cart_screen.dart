import 'package:bimobondapp/app/shop/domain/entities/cart_entity.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_bloc.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_event.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_state.dart';
import 'package:bimobondapp/app/shop/presentation/cubit/shop_cart_cubit.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart' as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/checkout_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_price.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const routeName = 'shop_cart';

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
    )..add(const ShopLoadCart());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _createBloc(),
      child: const ShopThemeScope(child: _CartView()),
    );
  }
}

class _CartView extends StatefulWidget {
  const _CartView();

  @override
  State<_CartView> createState() => _CartViewState();
}

class _CartViewState extends State<_CartView> {
  final UpdateCartItemUseCase _updateCartItem = shop_di.sl();
  final RemoveCartItemUseCase _removeCartItem = shop_di.sl();
  String? _updatingItemId;

  Future<void> _updateQuantity(CartItemEntity item, int quantity) async {
    setState(() => _updatingItemId = item.id);

    if (quantity <= 0) {
      final result = await _removeCartItem(item.id);
      result.fold(
        (failure) => _showError(failure),
        (_) {
          context.read<ShopBloc>().add(const ShopLoadCart());
          context.read<ShopCartCubit>().refresh();
        },
      );
    } else {
      final result = await _updateCartItem(
        cartItemId: item.id,
        quantity: quantity,
      );
      result.fold(
        (failure) => _showError(failure),
        (cart) {
          context.read<ShopBloc>().add(const ShopLoadCart());
          context.read<ShopCartCubit>().setCount(cart.itemCount);
        },
      );
    }

    if (mounted) setState(() => _updatingItemId = null);
  }

  void _showError(Object failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ErrorMessageResolver.resolve(failure))),
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const ShopBackButton(),
        iconTheme: IconThemeData(color: theme.onSurface),
        title: Text(
          l10n.shopCart,
          style: TextStyle(
            color: theme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BlocBuilder<ShopBloc, ShopState>(
        builder: (context, state) {
          final cart = state.cart;

          if (cart == null && state.error == null) {
            return const CartSkeleton();
          }

          if (cart == null || cart.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.shoppingCart,
                    size: 48,
                    color: theme.mutedText,
                  ),
                  const SizedBox(height: AppSizes.p16),
                  Text(
                    l10n.shopCartEmpty,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.p12),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final isUpdating = _updatingItemId == item.id;

                    return _CartItemTile(
                      item: item,
                      isUpdating: isUpdating,
                      onDecrease: () =>
                          _updateQuantity(item, item.quantity - 1),
                      onIncrease: () =>
                          _updateQuantity(item, item.quantity + 1),
                      onRemove: () => _updateQuantity(item, 0),
                    );
                  },
                ),
              ),
              _CheckoutBar(
                subtotalCoins: cart.subtotalCoins,
                onCheckout: () =>
                    context.pushNamed(CheckoutScreen.routeName),
                l10n: l10n,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.isUpdating,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartItemEntity item;
  final bool isUpdating;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: SafeNetworkImage(
              imageUrl: item.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (item.variant != null) ...[
                  const SizedBox(height: AppSizes.p4),
                  Text(
                    item.variant!.name,
                    style: TextStyle(color: theme.mutedText, fontSize: 12),
                  ),
                ],
                const SizedBox(height: AppSizes.p6),
                ProductPrice(
                  priceCoins: item.unitPriceCoins,
                  showCompareAt: false,
                  fontSize: 13,
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: theme.mutedText,
                ),
              ),
              if (isUpdating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyButton(icon: LucideIcons.minus, onTap: onDecrease),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p8,
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          color: theme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _QtyButton(icon: LucideIcons.plus, onTap: onIncrease),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.p4),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: theme.border),
        ),
        child: Icon(icon, size: 14, color: theme.onSurface),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.subtotalCoins,
    required this.onCheckout,
    required this.l10n,
  });

  final int subtotalCoins;
  final VoidCallback onCheckout;
  final AppLocalizations l10n;

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
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.shopSubtotal,
                  style: TextStyle(color: theme.mutedText, fontSize: 12),
                ),
                ProductPrice(
                  priceCoins: subtotalCoins,
                  showCompareAt: false,
                  fontSize: 16,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onCheckout,
            style: FilledButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: theme.onAccent,
              minimumSize: const Size(140, AppSizes.buttonHeightMd),
            ),
            child: Text(l10n.shopCheckoutAction),
          ),
        ],
      ),
    );
  }
}
