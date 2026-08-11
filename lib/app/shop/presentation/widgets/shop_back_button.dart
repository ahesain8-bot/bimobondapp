import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// iOS-style back control used on all shop AppBars.
class ShopBackButton extends StatelessWidget {
  const ShopBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        }
      },
      icon: DirectionalBackIcon(color: theme.onSurface),
    );
  }
}
