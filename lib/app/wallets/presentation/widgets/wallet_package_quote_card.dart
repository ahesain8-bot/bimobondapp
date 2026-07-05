import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_glass_style.dart';
import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WalletPackageQuoteCard extends StatelessWidget {
  const WalletPackageQuoteCard({
    required this.package,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CoinPackageEntity package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = WalletGlassStyle.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final priceLabel = MoneyFormatUtils.formatMoney(
      package.price,
      package.currencyCode,
      locale: locale,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(16),
          blurSigma: 16,
          backgroundColor: glass.surfaceFill,
          borderColor: selected ? primaryColor : glass.surfaceBorder,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (package.badge != null) ...[
                Text(
                  package.badge!,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                package.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: glass.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    LucideIcons.coins,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppSizes.p6),
                  Expanded(
                    child: Text(
                      '${package.coinAmount} ${l10n.coinsUnit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: glass.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (package.bonusCoins > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '+${package.bonusCoins} ${l10n.coinsUnit}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                priceLabel,
                style: TextStyle(
                  color: selected ? primaryColor : glass.secondaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletPackageQuoteChip extends StatelessWidget {
  const WalletPackageQuoteChip({
    required this.package,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CoinPackageEntity package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = WalletGlassStyle.of(context);
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final priceLabel = MoneyFormatUtils.formatMoney(
      package.price,
      package.currencyCode,
      locale: locale,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(14),
          blurSigma: 12,
          backgroundColor: selected
              ? primaryColor.withValues(alpha: 0.1)
              : glass.surfaceFill,
          borderColor: selected ? primaryColor : glass.surfaceBorder,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                package.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: glass.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${package.coinAmount} ${l10n.coinsUnit}',
                style: TextStyle(
                  color: glass.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                priceLabel,
                style: TextStyle(
                  color: selected ? primaryColor : glass.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
