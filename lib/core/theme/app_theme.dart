import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFF62872);
  static const Color secondaryColor = Color(0xFF2070C0);
  static const Color successColor = Color(0xFFE7F3EF);
  static const Color successAccent = Color(0xFF0F814A);
  static const Color errorColor = Color(0xFFF9E7E7);
  static const Color errorAccent = Color(0xFFC62828);

  /// Yellow repost chip used on the share sheet (matches prior UI).
  static const Color shareRepostBackground = Color(0xFFFACC15);

  /// Neutral circular chip behind share-sheet option icons.
  static Color shareIconMutedBackground(ColorScheme cs) {
    return Color.alphaBlend(
      cs.onSurface.withValues(
        alpha: cs.brightness == Brightness.light ? 0.08 : 0.14,
      ),
      cs.surface,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'Jannat',
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusMd)),
        ),
      ),
      extensions: [
        FeedOverlayTheme.forBrightness(Brightness.light),
        ShopTheme.forBrightness(
          Brightness.light,
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.light,
            primary: primaryColor,
            secondary: secondaryColor,
            surface: Colors.white,
          ),
        ),
        ChatTheme.forBrightness(
          Brightness.light,
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.light,
            primary: primaryColor,
            secondary: secondaryColor,
            surface: Colors.white,
          ),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      fontFamily: 'Jannat',
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: const Color(0xFF1F1F1F),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dialogTheme: const DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusMd)),
        ),
      ),
      extensions: [
        FeedOverlayTheme.forBrightness(Brightness.dark),
        ShopTheme.forBrightness(
          Brightness.dark,
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.dark,
            primary: primaryColor,
            secondary: secondaryColor,
            surface: const Color(0xFF1F1F1F),
          ),
        ),
        ChatTheme.forBrightness(
          Brightness.dark,
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.dark,
            primary: primaryColor,
            secondary: secondaryColor,
            surface: const Color(0xFF1F1F1F),
          ),
        ),
      ],
    );
  }
}
