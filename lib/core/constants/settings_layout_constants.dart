import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class SettingsLayoutConstants {
  SettingsLayoutConstants._();

  static const double horizontalPadding = AppSizes.p16;
  static const double bodyTopPadding = AppSizes.p4;
  static const double bodyVerticalPadding = AppSizes.p8;
  static const double pageTitleFontSize = 28;
  static const double pageTitleBottomSpacing = AppSizes.p20;

  static const double sectionTitleTopPadding = AppSizes.p16;
  static const double sectionTitleBottomPadding = AppSizes.p8;
  static const double sectionTitleHorizontalPadding = AppSizes.p4;
  static const double sectionTitleFontSize = 13;
  static const double sectionTitleColorAlpha = 0.45;

  static const Color pageBackgroundLight = Color(0xFFF2F2F2);
  static const Color pageBackgroundDark = Color(0xFF121212);
  static const Color cardBackgroundLight = Colors.white;
  static const Color cardBackgroundDark = Color(0xFF1C1C1E);

  /// Shared light borders used by activity / app-bar helpers.
  static const Color groupBorderLight = Color(0xFFE5E5E5);
  static const Color groupBorderDark = Color(0xFF3D3D3D);

  static Color pageBackground(ThemeData theme) =>
      theme.brightness == Brightness.dark
      ? pageBackgroundDark
      : pageBackgroundLight;

  static Color cardBackground(ThemeData theme) =>
      theme.brightness == Brightness.dark
      ? cardBackgroundDark
      : cardBackgroundLight;

  static Color groupBorderColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
      ? groupBorderDark
      : groupBorderLight;

  static Color iconColor(ThemeData theme) =>
      theme.colorScheme.onSurface.withValues(alpha: 0.55);

  static Color chevronColor(ThemeData theme) =>
      theme.colorScheme.onSurface.withValues(alpha: 0.28);

  static Color trailingTextColor(ThemeData theme) =>
      theme.colorScheme.onSurface.withValues(alpha: 0.4);

  static const double groupSpacing = AppSizes.p8;
  static const double groupRadius = 12;
  static const double tileHorizontalPadding = AppSizes.p16;
  static const double tileVerticalPadding = 2;
  static const double iconContainerRadius = AppSizes.p8;
  static const double leadingIconSize = 22;
  static const double leadingGap = 14;
  static const double itemTitleFontSize = 16;
  static const double trailingFontSize = 14;
  static const double chevronSize = 18;
  static const double chevronGap = AppSizes.p4;
  static const double logoutTopSpacing = AppSizes.p24;
  static const double bottomSpacing = 40;
  static const double sheetItemSpacing = AppSizes.p20;
  static const double logoutFontSize = 16;
  static const Color logoutColor = Color(0xFFFF3B30);
}
