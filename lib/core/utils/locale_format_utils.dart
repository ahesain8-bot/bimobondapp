import 'dart:ui';

/// Formats numbers and timers using locale-appropriate digits (e.g. Arabic-Indic).
class LocaleFormatUtils {
  LocaleFormatUtils._();

  static const _westernDigits = '0123456789';
  static const _easternArabicDigits = '٠١٢٣٤٥٦٧٨٩';

  static bool _usesEasternArabicDigits(Locale locale) {
    return locale.languageCode == 'ar';
  }

  static String localizeDigits(String value, Locale locale) {
    if (!_usesEasternArabicDigits(locale)) return value;

    final buffer = StringBuffer();
    for (final char in value.split('')) {
      final index = _westernDigits.indexOf(char);
      if (index >= 0) {
        buffer.write(_easternArabicDigits[index]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static String twoDigitTimeUnit(int value, Locale locale) {
    return localizeDigits(value.toString().padLeft(2, '0'), locale);
  }
}
