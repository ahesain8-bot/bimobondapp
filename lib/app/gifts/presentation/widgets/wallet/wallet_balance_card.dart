import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_glass_style.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    required this.balance,
    required this.pulseAnimation,
    this.errorMessage,
    super.key,
  });

  final int balance;
  final Animation<double> pulseAnimation;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glass = WalletGlassStyle.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(28),
        blurSigma: 24,
        backgroundColor: glass.cardFill,
        borderColor: glass.cardBorder,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p20,
          vertical: 24,
        ),
        child: Column(
          children: [
            CustomText(
              l10n.walletBalanceLabel.toUpperCase(),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: glass.secondaryText,
            ),
            const SizedBox(height: AppSizes.p12),
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                final glowScale = 1.0 + (pulseAnimation.value * 0.06);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: glowScale,
                      child: const AppCoinIcon(size: 30),
                    ),
                    const SizedBox(width: AppSizes.p10),
                    Text(
                      '$balance',
                      style: TextStyle(
                        color: glass.primaryText,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.coinsUnit,
                      style: TextStyle(
                        color: glass.secondaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSizes.p16),
              LiquidGlassSurface(
                borderRadius: BorderRadius.circular(12),
                blurSigma: 12,
                backgroundColor:
                    theme.colorScheme.error.withValues(alpha: 0.12),
                borderColor:
                    theme.colorScheme.error.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
