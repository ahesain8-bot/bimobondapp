import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:flutter/material.dart';

/// Marketplace design tokens — extends [ShopTheme] with premium layout constants.
@immutable
class MarketplaceTheme {
  const MarketplaceTheme._({
    required this.shop,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.card,
    required this.onSurface,
    required this.mutedText,
    required this.success,
    required this.auctionAccent,
    required this.heroCarouselGradient,
  });

  final ShopTheme shop;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color card;
  final Color onSurface;
  final Color mutedText;
  final Color success;
  final Color auctionAccent;
  final LinearGradient heroCarouselGradient;

  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static double heroCarouselHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.18).clamp(150.0, 170.0);
  }

  static MarketplaceTheme of(BuildContext context) {
    final shop = ShopTheme.of(context);
    return MarketplaceTheme._(
      shop: shop,
      primary: shop.primary,
      secondary: shop.accentCyan,
      background: shop.background,
      surface: shop.surface,
      card: shop.card,
      onSurface: shop.onSurface,
      mutedText: shop.mutedText,
      success: const Color(0xFF16A34A),
      auctionAccent: const Color(0xFF7C3AED),
      heroCarouselGradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color.alphaBlend(
            shop.primary.withValues(alpha: 0.16),
            shop.card,
          ),
          Color.alphaBlend(
            shop.accentCyan.withValues(alpha: 0.22),
            shop.card,
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration({Color? color, double radius = radiusMd}) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: cardShadow,
      border: Border.all(color: shop.border.withValues(alpha: 0.35)),
    );
  }

  BoxDecoration productCardDecoration({Color? color, double radius = radiusSm}) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: shop.border.withValues(alpha: 0.12)),
    );
  }

  BoxDecoration pillDecoration({required bool selected}) {
    return BoxDecoration(
      color: selected ? primary : surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(
        color: selected ? primary : shop.border.withValues(alpha: 0.5),
      ),
    );
  }
}

class MarketplaceThemeScope extends StatelessWidget {
  const MarketplaceThemeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShopThemeScope(child: child);
  }
}
