import 'package:bimobondapp/core/utils/system_ui_overlay_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shop colors follow app [ThemeData] / [ColorScheme], using [ColorScheme.primary].
@immutable
class ShopTheme extends ThemeExtension<ShopTheme> {
  const ShopTheme({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.accentPink,
    required this.onAccent,
    required this.accentCyan,
    required this.mutedText,
    required this.priceText,
    required this.compareAtText,
    required this.discountBadgeBackground,
    required this.discountBadgeText,
    required this.liveBadgeBackground,
    required this.liveBadgeText,
    required this.onSurface,
    required this.shimmerBase,
    required this.shimmerHighlight,
    this.cardRadius = 22,
    this.chipRadius = 20,
    this.searchRadius = 18,
    this.buttonRadius = 18,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  /// App primary (kept name for existing call sites).
  final Color accentPink;
  final Color onAccent;
  final Color accentCyan;
  final Color mutedText;
  final Color priceText;
  final Color compareAtText;
  final Color discountBadgeBackground;
  final Color discountBadgeText;
  final Color liveBadgeBackground;
  final Color liveBadgeText;
  final Color onSurface;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final double cardRadius;
  final double chipRadius;
  final double searchRadius;
  final double buttonRadius;

  /// Alias for [accentPink] — app primary color.
  Color get primary => accentPink;

  static ShopTheme forBrightness(Brightness brightness, ColorScheme scheme) {
    final isDark = brightness == Brightness.dark;
    final onSurface = scheme.onSurface;
    final primary = scheme.primary;
    final onPrimary = scheme.onPrimary;
    final background = scheme.surface;
    final surface = isDark ? scheme.surfaceContainerHighest : scheme.surface;
    final card = isDark ? scheme.surfaceContainerHigh : scheme.surface;

    return ShopTheme(
      background: background,
      surface: surface,
      card: card,
      border: onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
      accentPink: primary,
      onAccent: onPrimary,
      accentCyan: scheme.secondary,
      mutedText: onSurface.withValues(alpha: isDark ? 0.6 : 0.55),
      priceText: onSurface,
      compareAtText: onSurface.withValues(alpha: isDark ? 0.4 : 0.38),
      discountBadgeBackground: primary.withValues(alpha: isDark ? 0.28 : 0.12),
      discountBadgeText: isDark ? onPrimary : primary,
      liveBadgeBackground: primary,
      liveBadgeText: onPrimary,
      onSurface: onSurface,
      shimmerBase: Color.alphaBlend(
        onSurface.withValues(alpha: isDark ? 0.12 : 0.06),
        background,
      ),
      shimmerHighlight: Color.alphaBlend(
        onSurface.withValues(alpha: isDark ? 0.2 : 0.1),
        background,
      ),
    );
  }

  static ShopTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ShopTheme>() ??
        forBrightness(theme.brightness, theme.colorScheme);
  }

  static List<ThemeExtension<dynamic>> wrapExtensions(BuildContext context) {
    final theme = Theme.of(context);
    final List<ThemeExtension<dynamic>> extensions = [];
    for (final Object ext in theme.extensions.values) {
      if (ext is ThemeExtension && ext is! ShopTheme) {
        extensions.add(ext as ThemeExtension<dynamic>);
      }
    }
    extensions.add(forBrightness(theme.brightness, theme.colorScheme));
    return extensions;
  }

  @override
  ShopTheme copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? accentPink,
    Color? onAccent,
    Color? accentCyan,
    Color? mutedText,
    Color? priceText,
    Color? compareAtText,
    Color? discountBadgeBackground,
    Color? discountBadgeText,
    Color? liveBadgeBackground,
    Color? liveBadgeText,
    Color? onSurface,
    Color? shimmerBase,
    Color? shimmerHighlight,
    double? cardRadius,
    double? chipRadius,
    double? searchRadius,
    double? buttonRadius,
  }) {
    return ShopTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      accentPink: accentPink ?? this.accentPink,
      onAccent: onAccent ?? this.onAccent,
      accentCyan: accentCyan ?? this.accentCyan,
      mutedText: mutedText ?? this.mutedText,
      priceText: priceText ?? this.priceText,
      compareAtText: compareAtText ?? this.compareAtText,
      discountBadgeBackground:
          discountBadgeBackground ?? this.discountBadgeBackground,
      discountBadgeText: discountBadgeText ?? this.discountBadgeText,
      liveBadgeBackground: liveBadgeBackground ?? this.liveBadgeBackground,
      liveBadgeText: liveBadgeText ?? this.liveBadgeText,
      onSurface: onSurface ?? this.onSurface,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      cardRadius: cardRadius ?? this.cardRadius,
      chipRadius: chipRadius ?? this.chipRadius,
      searchRadius: searchRadius ?? this.searchRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
    );
  }

  @override
  ShopTheme lerp(ThemeExtension<ShopTheme>? other, double t) {
    if (other is! ShopTheme) return this;
    return ShopTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      accentPink: Color.lerp(accentPink, other.accentPink, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      priceText: Color.lerp(priceText, other.priceText, t)!,
      compareAtText: Color.lerp(compareAtText, other.compareAtText, t)!,
      discountBadgeBackground:
          Color.lerp(discountBadgeBackground, other.discountBadgeBackground, t)!,
      discountBadgeText:
          Color.lerp(discountBadgeText, other.discountBadgeText, t)!,
      liveBadgeBackground:
          Color.lerp(liveBadgeBackground, other.liveBadgeBackground, t)!,
      liveBadgeText: Color.lerp(liveBadgeText, other.liveBadgeText, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      chipRadius: chipRadius + (other.chipRadius - chipRadius) * t,
      searchRadius: searchRadius + (other.searchRadius - searchRadius) * t,
      buttonRadius: buttonRadius + (other.buttonRadius - buttonRadius) * t,
    );
  }
}

/// Applies shop colors and restores readable status-bar icons (time / battery)
/// after leaving immersive feed routes.
class ShopThemeScope extends StatelessWidget {
  const ShopThemeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final shopTheme = ShopTheme.forBrightness(brightness, theme.colorScheme);
    final overlay = appContentSystemUiOverlayStyle(brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Theme(
        data: theme.copyWith(
          scaffoldBackgroundColor: shopTheme.background,
          colorScheme: theme.colorScheme.copyWith(
            primary: shopTheme.primary,
            onPrimary: shopTheme.onAccent,
          ),
          appBarTheme: theme.appBarTheme.copyWith(
            systemOverlayStyle: overlay,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: shopTheme.primary,
              foregroundColor: shopTheme.onAccent,
            ),
          ),
          extensions: ShopTheme.wrapExtensions(context),
        ),
        child: child,
      ),
    );
  }
}
