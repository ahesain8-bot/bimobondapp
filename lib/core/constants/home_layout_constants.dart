/// Layout and motion constants for [MainScreen] and the home feed.
class HomeLayoutConstants {
  HomeLayoutConstants._();

  static const double mainBottomNavHeight = 100;
  static const double feedPostBottomPadding = 88;

  static const double bottomNavTopPadding = 12;
  static const double bottomNavSafeExtra = 8;
  static const double navIconSize = 26;
  static const double navLabelFontSize = 10;
  static const double navItemBottomPadding = 4;

  static const double liveIconSize = 28;
  static const double feedTopBarHeight = 44;
  static const double feedTopTabsTopPadding = 16;
  /// Gap between the feed top bar (Following / For You) and overlay content.
  static const double feedTopBarBottomGap = 12;
  static const double feedOverlayHorizontalPadding = 8;

  static const double addButtonWidth = 48;
  static const double addButtonHeight = 40;
  static const double addButtonRadius = 14;
  static const double addButtonIconSize = 26;
  static const double addButtonShadowBlur = 10;
  static const double addButtonShadowOffsetY = 4;

  static const double navBlurSigma = 10;
  static const double tabsBlurSigma = 12;

  static const double tabPillDividerWidth = 1;
  static const double tabPillDividerHeight = 14;
  static const double tabSelectedFontSize = 17;
  static const double tabUnselectedFontSize = 16;

  static const double progressBarMinHeight = 1.5;
  static const Duration videoProgressDuration = Duration(seconds: 15);

  static const int feedPageSize = 10;
  static const int feedPrefetchThresholdOffset = 2;
  static const int feedPrefetchMinPosts = 3;

  static const Duration tabRefreshTimeout = Duration(seconds: 30);
  static const double tabRefreshDisplacement = 40;
}
