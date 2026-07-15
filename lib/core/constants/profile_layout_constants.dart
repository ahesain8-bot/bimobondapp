import 'package:flutter/material.dart';

/// Layout constants for the profile screen.
class ProfileLayoutConstants {
  ProfileLayoutConstants._();

  static const double avatarRadius = 48;
  static const double headerHorizontalPadding = 16;
  static const double headerVerticalPadding = 8;
  static const double headerMenuIconSize = 24;

  /// TikTok-style compact pill beside display name.
  static const double editPillHeight = 28;
  static const double editPillIconSize = 18;
  static const double editPillGapFromName = 8;
  static const Color editPillBackgroundLight = Color(0xFFF1F1F2);

  static const double tabSwitcherRadius = 14;
  static const double tabSwitcherPadding = 4;
  static const double tabButtonRadius = 10;
  static const double tabButtonVerticalPadding = 12;
  static const Duration tabAnimationDuration = Duration(milliseconds: 180);

  static const int gridCrossAxisCount = 3;

  /// TikTok-style tight grid with ~1px gaps.
  static const double gridSpacing = 1;

  /// Portrait tiles — shorter than full 9:16, still TikTok-style grid.
  static const double gridAspectRatio = 9 / 10;
  static const double gridItemRadius = 0;
  static const double gridPlaceholderIconSize = 34;
  static const double gridViewCountIconSize = 12;
  static const double gridViewCountFontSize = 12;

  static const int postsPageSize = 10;

  /// Feed API sort: newest posts first (`LATEST`).
  static const String postsSortNewestFirst = 'LATEST';
  static const double scrollLoadMoreThreshold = 200;

  static const int tabCount = 5;
  static const int postsTabIndex = 0;
  static const int repostsTabIndex = 1;
  static const int onlyMeTabIndex = 2;
  static const int likedTabIndex = 3;
  static const int savedTabIndex = 4;
  static const String onlyMePrivacyStatus = 'PRIVATE';
  static const double iconTabBarHeight = 48;
  static const double iconTabSize = 22;
  static const double iconTabIndicatorHeight = 2;
  static const double iconTabIndicatorWidth = 56;
}
