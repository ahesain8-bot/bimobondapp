import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF00F2EA);
  static const Color primaryDark = Color(0xFF00D4D0);
  static const Color primaryLight = Color(0xFF33F4ED);

  // Secondary Colors
  static const Color secondary = Color(0xFFFE2C55);
  static const Color secondaryDark = Color(0xFFE01E48);
  static const Color secondaryLight = Color(0xFFFF4D73);

  // Background Colors
  static const Color background = Color(0xFF000000);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2D2D2D);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textHint = Color(0xFF666666);

  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF1744);
  static const Color info = Color(0xFF00B0FF);

  // Live Colors
  static const Color liveRed = Color(0xFFFE2C55);
  static const Color liveGradientStart = Color(0xFFFE2C55);
  static const Color liveGradientEnd = Color(0xFFFF6B6B);

  // Gift Colors
  static const Color coinGold = Color(0xFFFFD700);
  static const Color coinSilver = Color(0xFFC0C0C0);
  static const Color coinBronze = Color(0xFFCD7F32);

  // Overlay Colors
  static const Color overlayDark = Color(0xCC000000);
  static const Color overlayLight = Color(0x4DFFFFFF);
  static const Color blurOverlay = Color(0x40000000);

  // Gradient Definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liveGradient = LinearGradient(
    colors: [liveGradientStart, liveGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Colors.black54],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
