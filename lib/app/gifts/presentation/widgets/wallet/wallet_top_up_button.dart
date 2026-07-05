import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_glass_style.dart';
import 'package:bimobondapp/app/wallets/domain/utils/wallet_coin_pricing.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class WalletTopUpButton extends StatelessWidget {
  const WalletTopUpButton({
    required this.quote,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final WalletTopUpQuote quote;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final priceLabel = MoneyFormatUtils.formatMoney(
      quote.price,
      quote.currencyCode,
      locale: locale,
    );

    return WalletGlassPrimaryButton(
      enabled: enabled && quote.isValid,
      onPressed: enabled && quote.isValid ? onPressed : null,
      child: CustomText(
        quote.isValid
            ? '${l10n.walletTopUpButton} ($priceLabel)'
            : l10n.walletTopUpButton,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }
}
