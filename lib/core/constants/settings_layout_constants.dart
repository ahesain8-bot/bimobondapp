import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class SettingsLayoutConstants {
  SettingsLayoutConstants._();

  static const double horizontalPadding = AppSizes.p16;
  static const double bodyVerticalPadding = AppSizes.p8;
  static const double sectionTitleTopPadding = AppSizes.p16;
  static const double sectionTitleBottomPadding = AppSizes.p8;
  static const double sectionTitleHorizontalPadding = AppSizes.p4;
  static const double sectionTitleFontSize = 13;
  static const double sectionTitleLetterSpacing = 0.5;
  static const double sectionTitleColorAlpha = 0.5;

  /// Light gray borders for settings groups (light / dark).
  static const Color groupBorderLight = Color(0xFFE5E5E5);
  static const Color groupBorderDark = Color(0xFF3D3D3D);
  static const Color groupDividerLight = Color(0xFFEBEBEB);
  static const Color groupDividerDark = Color(0xFF383838);

  static Color groupBorderColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? groupBorderDark
          : groupBorderLight;

  static Color groupDividerColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? groupDividerDark
          : groupDividerLight;
  static const double groupSpacing = AppSizes.p12;
  static const double groupRadius = AppSizes.p16;
  static const double dividerIndent = 56;
  static const double dividerEndIndent = AppSizes.p16;
  static const double tileHorizontalPadding = AppSizes.p16;
  static const double tileVerticalPadding = 2;
  static const double iconContainerPadding = AppSizes.p8;
  static const double iconContainerRadius = AppSizes.p8;
  static const double iconBackgroundAlpha = 0.1;
  static const double leadingIconSize = 20;
  static const double itemTitleFontSize = 15;
  static const double trailingFontSize = 14;
  static const double trailingTextAlpha = 0.4;
  static const double chevronSize = 14;
  static const double chevronAlpha = 0.2;
  static const double chevronGap = AppSizes.p4;
  static const double logoutTopSpacing = AppSizes.p32;
  static const double bottomSpacing = 40;
  static const double appBarDividerHeight = 1;
  static const double sheetRadius = AppSizes.p20;
  static const double sheetVerticalPadding = AppSizes.p20;
  static const double sheetTitleFontSize = 18;
  static const double sheetItemSpacing = AppSizes.p20;
  static const double logoutFontSize = 16;
  static const Color logoutColor = Color(0xFFFF4D4D);
}