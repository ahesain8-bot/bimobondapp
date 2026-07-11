import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_glass_style.dart';
import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/domain/utils/wallet_coin_pricing.dart';
import 'package:bimobondapp/app/wallets/presentation/widgets/wallet_package_quote_card.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WalletCustomAmountSection extends StatelessWidget {
  const WalletCustomAmountSection({
    required this.controller,
    required this.packages,
    this.unitPrice = 0.0099,
    this.currencyCode = 'USD',
    this.pricingPreview,
    this.previewForCoins,
    this.loadingPricingPreview = false,
    this.onChanged,
    this.onPackageSelected,
    super.key,
  });

  final TextEditingController controller;
  final List<CoinPackageEntity> packages;
  final double unitPrice;
  final String currencyCode;
  final AuctionPricingPreviewEntity? pricingPreview;
  final int? previewForCoins;
  final bool loadingPricingPreview;
  final ValueChanged<int>? onChanged;
  final ValueChanged<CoinPackageEntity>? onPackageSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final glass = WalletGlassStyle.of(context);
    final locale = Localizations.localeOf(context);
    final coins = WalletCoinPricing.parseCoinsInput(controller.text);
    final packageMatch = WalletCoinPricing.packageForCoins(coins, packages);
    final needsApiPreview = coins > 0 && packageMatch == null;
    final hasApiPreview = needsApiPreview &&
        pricingPreview != null &&
        previewForCoins == coins;

    final receiveCoins = packageMatch != null
        ? packageMatch.coinAmount
        : hasApiPreview
        ? coins
        : coins;

    final String priceLabel;
    if (coins <= 0) {
      priceLabel = '—';
    } else if (packageMatch != null) {
      priceLabel = MoneyFormatUtils.formatMoney(
        packageMatch.price,
        packageMatch.currencyCode,
        locale: locale,
      );
    } else if (loadingPricingPreview) {
      priceLabel = l10n.walletPricingPreviewLoading;
    } else if (hasApiPreview) {
      final previewQuote = WalletTopUpQuote.fromPricingPreview(
        pricingPreview!,
        requestedCoins: coins,
      );
      priceLabel = MoneyFormatUtils.formatMoney(
        previewQuote.price,
        previewQuote.currencyCode,
        locale: locale,
      );
    } else {
      priceLabel = '—';
    }

    final coinsLabel = receiveCoins > 0
        ? LocaleFormatUtils.localizeDigits(receiveCoins.toString(), locale)
        : '—';
    final activePackages =
        packages.where((pack) => pack.isActive).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          l10n.walletCustomAmountTitle,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        const SizedBox(height: AppSizes.p10),
        LiquidGlassSurface(
          borderRadius: BorderRadius.circular(20),
          blurSigma: 20,
          backgroundColor: glass.cardFill,
          borderColor: glass.cardBorder,
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText(
                l10n.walletCustomCoinsLabel,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: glass.secondaryText,
              ),
              const SizedBox(height: AppSizes.p8),
              LiquidGlassSurface(
                borderRadius: BorderRadius.circular(14),
                blurSigma: 12,
                backgroundColor: glass.surfaceFill,
                borderColor: glass.surfaceBorder,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: glass.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  cursorColor: Theme.of(context).colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: l10n.walletCustomCoinsHint,
                    hintStyle: TextStyle(
                      color: glass.hintText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 12, right: 4),
                      child: AppCoinIcon(size: 20),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    suffixText: l10n.coinsUnit,
                    suffixStyle: TextStyle(
                      color: glass.secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) =>
                      onChanged?.call(WalletCoinPricing.parseCoinsInput(value)),
                ),
              ),
              if (activePackages.isNotEmpty) ...[
                const SizedBox(height: AppSizes.p12),
                CustomText(
                  l10n.walletPackageQuotes,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: glass.secondaryText,
                ),
                const SizedBox(height: AppSizes.p8),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activePackages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final pack = activePackages[index];
                      return WalletPackageQuoteChip(
                        package: pack,
                        selected: coins == pack.coinAmount,
                        onTap: () {
                          controller.text = '${pack.coinAmount}';
                          onPackageSelected?.call(pack);
                          onChanged?.call(pack.coinAmount);
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.p12),
              Row(
                children: [
                  Expanded(
                    child: _QuoteTile(
                      label: l10n.walletCustomCoinsReceive,
                      value: receiveCoins > 0
                          ? l10n.walletCustomCoinsValue(coinsLabel)
                          : '—',
                      glass: glass,
                      showCoinIcon: receiveCoins > 0,
                    ),
                  ),
                  const SizedBox(width: AppSizes.p10),
                  Expanded(
                    child: _QuoteTile(
                      label: packageMatch != null
                          ? l10n.walletPackageQuotePrice
                          : hasApiPreview
                          ? l10n.walletPricingPreviewCost
                          : l10n.walletCustomYouPay,
                      value: priceLabel,
                      glass: glass,
                      emphasized: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({
    required this.label,
    required this.value,
    required this.glass,
    this.emphasized = false,
    this.showCoinIcon = false,
  });

  final String label;
  final String value;
  final WalletGlassStyle glass;
  final bool emphasized;
  final bool showCoinIcon;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(12),
      blurSigma: 10,
      backgroundColor: glass.surfaceFill,
      borderColor: glass.surfaceBorder,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: glass.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          showCoinIcon
              ? AppCoinAmount(
                  iconSize: 14,
                  text: value,
                  style: TextStyle(
                    color: emphasized
                        ? Theme.of(context).colorScheme.primary
                        : glass.primaryText,
                    fontSize: emphasized ? 15 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: emphasized
                        ? Theme.of(context).colorScheme.primary
                        : glass.primaryText,
                    fontSize: emphasized ? 15 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ],
      ),
    );
  }
}
