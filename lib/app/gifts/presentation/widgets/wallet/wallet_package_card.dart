import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_coin_package.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_glass_style.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WalletPackageCard extends StatelessWidget {
  const WalletPackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final WalletCoinPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = WalletGlassStyle.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            LiquidGlassSurface(
              borderRadius: BorderRadius.circular(16),
              blurSigma: 16,
              backgroundColor: glass.surfaceFill,
              borderColor: selected ? primaryColor : glass.surfaceBorder,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppCoinIcon(size: 16),
                        const SizedBox(width: AppSizes.p6),
                        CustomText(
                          '${package.coins}',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p4),
                    CustomText(
                      '\$${package.priceUsd.toStringAsFixed(2)}',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      variant: TextVariant.secondary,
                    ),
                  ],
                ),
              ),
            ),
            if (package.badge != null)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: LiquidGlassSurface(
                    borderRadius: BorderRadius.circular(8),
                    blurSigma: 10,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.88,
                    ),
                    borderColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Text(
                      package.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            if (selected)
              Positioned(
                bottom: 8,
                right: 8,
                child: LiquidGlassSurface(
                  borderRadius: BorderRadius.circular(20),
                  blurSigma: 8,
                  backgroundColor: primaryColor,
                  borderColor: primaryColor.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.check, color: Colors.white, size: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
