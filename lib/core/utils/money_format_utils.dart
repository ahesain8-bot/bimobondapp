import 'dart:ui';

import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:intl/intl.dart';

/// Formats real-money amounts with ISO 4217 [currencyCode] — never hardcode `$`.
abstract final class MoneyFormatUtils {
  MoneyFormatUtils._();

  static String formatMoney(
    num amount,
    String currencyCode, {
    Locale? locale,
  }) {
    final code = currencyCode.trim().isEmpty ? 'USD' : currencyCode.trim();
    final loc = locale ?? const Locale('en');
    try {
      return NumberFormat.simpleCurrency(
        locale: loc.toString(),
        name: code,
      ).format(amount);
    } catch (_) {
      final digits = LocaleFormatUtils.localizeDigits(
        amount is int || amount == amount.roundToDouble()
            ? amount.round().toString()
            : amount.toStringAsFixed(2),
        loc,
      );
      return '$digits $code';
    }
  }
}

/// Coin amounts use the app coin label — not currency formatting.
abstract final class CoinFormatUtils {
  CoinFormatUtils._();

  static String formatCoins(int coins, Locale locale, {String? label}) {
    final digits = LocaleFormatUtils.localizeDigits(coins.toString(), locale);
    if (label == null || label.isEmpty) return digits;
    return '$digits $label';
  }
}
