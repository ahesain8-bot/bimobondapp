import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/cart_button.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ShopHeader extends StatelessWidget implements PreferredSizeWidget {
  const ShopHeader({
    required this.onSearchTap,
    this.cartCount = 0,
    this.onCartTap,
    this.onOrdersTap,
    this.showCart = false,
    super.key,
  });

  final int cartCount;
  final VoidCallback onSearchTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onOrdersTap;
  final bool showCart;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: theme.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p8,
            AppSizes.p4,
            AppSizes.p12,
            AppSizes.p8,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: DirectionalBackIcon(size: 20, color: theme.onSurface),
              ),
              Expanded(
                child: Material(
                  color: theme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.searchRadius),
                    side: BorderSide(color: theme.border),
                  ),
                  child: InkWell(
                    onTap: onSearchTap,
                    borderRadius: BorderRadius.circular(theme.searchRadius),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 18,
                            color: theme.mutedText,
                          ),
                          const SizedBox(width: AppSizes.p8),
                          Expanded(
                            child: Text(
                              l10n.shopSearchHint,
                              style: TextStyle(
                                color: theme.mutedText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p4),
              if (onOrdersTap != null)
                IconButton(
                  tooltip: l10n.shopOrders,
                  onPressed: onOrdersTap,
                  icon: Icon(
                    LucideIcons.package,
                    color: theme.onSurface,
                    size: 20,
                  ),
                ),
              if (showCart && onCartTap != null)
                CartButton(count: cartCount, onTap: onCartTap!),
            ],
          ),
        ),
      ),
    );
  }
}
