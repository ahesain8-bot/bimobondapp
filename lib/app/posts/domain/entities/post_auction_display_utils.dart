import 'dart:ui';

import 'package:bimobondapp/core/utils/locale_format_utils.dart';

String formatAuctionPricingCoins(num value, Locale locale) {
  final text = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return LocaleFormatUtils.localizeDigits(text, locale);
}
