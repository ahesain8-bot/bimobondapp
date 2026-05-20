import 'package:flutter/material.dart';

/// Layout constants for the profile screen.
class ProfileLayoutConstants {
  ProfileLayoutConstants._();

  static const double avatarRadius = 42;
  static const double headerHorizontalPadding = 16;
  static const double headerVerticalPadding = 14;
  static const double headerMenuIconSize = 24;

  /// TikTok-style compact pill beside display name.
  static const double editPillHeight = 32;
  static const double editPillIconSize = 18;
  static const double editPillGapFromName = 8;
  static const Color editPillBackgroundLight = Color(0xFFF1F1F2);

  static const double tabSwitcherRadius = 14;
  static const double tabSwitcherPadding = 4;
  static const double tabButtonRadius = 10;
  static const double tabButtonVerticalPadding = 12;
  static const Duration tabAnimationDuration = Duration(milliseconds: 180);

  static const int gridCrossAxisCount = 3;
  static const double gridSpacing = 6;
  static const double gridAspectRatio = 0.72;
  static const double gridItemRadius = 8;
  static const double gridPlaceholderIconSize = 34;

  static const int postsPageSize = 18;
  static const double scrollLoadMoreThreshold = 200;

  static const int tabCount = 3;
  static const double iconTabBarHeight = 48;
  static const double iconTabSize = 22;
  static const double iconTabIndicatorHeight = 2;
  static const double iconTabIndicatorWidth = 56;
}
