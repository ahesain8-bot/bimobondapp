import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class NotificationsLayoutConstants {
  NotificationsLayoutConstants._();

  static const double cardRadius = 20;
  static const double cardPadding = AppSizes.p16;
  static const double headerTitleSize = 22;
  static const double chipHeight = 36;
  static const double chipRadius = 999;
  static const double chipHorizontalPadding = 14;
  static const double chipSpacing = AppSizes.p8;
  static const double avatarRadius = 22;
  static const double statusDotSize = 10;
  static const double unreadDotSize = 8;
  static const double itemVerticalPadding = AppSizes.p12;
  static const double contextTagRadius = 8;
  static const double mediaCardRadius = 12;
  static const double actionButtonHeight = 36;
  static const double actionButtonRadius = 999;

  static const Color chipSelectedBorderLight = Color(0xFF1A1A1A);
  static const Color chipUnselectedBgLight = Color(0xFFF3F3F3);
  static const Color chipUnselectedBgDark = Color(0xFF2A2A2A);
  static const Color unreadDotColor = Color(0xFF34C759);
  static const Color dottedDividerLight = Color(0xFFD6D6D6);
  static const Color dottedDividerDark = Color(0xFF4A4A4A);
  static const Color mediaCardBgLight = Color(0xFFF5F5F5);
  static const Color mediaCardBgDark = Color(0xFF2A2A2A);

  static Color chipUnselectedBackground(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? chipUnselectedBgDark
          : chipUnselectedBgLight;

  static Color dottedDividerColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? dottedDividerDark
          : dottedDividerLight;

  static Color mediaCardBackground(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? mediaCardBgDark
          : mediaCardBgLight;
}
