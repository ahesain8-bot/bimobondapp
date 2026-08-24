import 'package:bimobondapp/app/marketplace/presentation/pages/liked_products_screen.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/shop/presentation/cubit/shop_cart_cubit.dart';
import 'package:bimobondapp/app/shop/presentation/pages/cart_screen.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/cart_button.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MarketplaceHeader extends StatelessWidget implements PreferredSizeWidget {
  const MarketplaceHeader({
    this.onCartTap,
    this.onLikedTap,
    super.key,
  });

  final VoidCallback? onCartTap;
  final VoidCallback? onLikedTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return CustomAppBar(
      title: l10n.marketplaceTitle,
      showBackButton: true,
      hideBottomDivider: true,
      backgroundColor: theme.background,
      actions: [
        IconButton(
          tooltip: l10n.marketplaceLikedProducts,
          onPressed: onLikedTap ??
              () => context.pushNamed(LikedProductsScreen.routeName),
          icon: Icon(LucideIcons.heart, color: theme.onSurface, size: 20),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSizes.p8),
          child: BlocBuilder<ShopCartCubit, int>(
            builder: (context, count) {
              return CartButton(
                count: count,
                onTap: onCartTap ?? () => context.pushNamed(CartScreen.routeName),
              );
            },
          ),
        ),
      ],
    );
  }
}
