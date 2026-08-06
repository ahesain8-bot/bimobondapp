/// Layout and motion constants for [MainScreen] and the home feed.
library;

import 'package:flutter/widgets.dart';

class HomeLayoutConstants {
  HomeLayoutConstants._();

  static const double mainBottomNavHeight = 100;

  static const double feedPostBottomPadding = 76;

  /// TikTok-style search pill above the video progress bar.
  static const double feedSearchHintBarHeight = 40.0;
  static const double feedSearchHintBottomGap = 0.0;

  /// Instagram-style "interested?" bar above the bottom nav (every N posts).
  static const double feedInterestPromptHeight = 56.0;
  static const int feedInterestPromptEveryNPosts = 20;

  /// Space between the home tab bar and the search/progress stack on the post.
  static const double feedPostStackChromeGapAboveNav = 0.0;

  /// Gap between the search/progress stack and caption / music overlay.
  static const double feedCaptionGapBelowSearchChrome = 4.0;

  static const double bottomNavTopPadding = 8;
  static const double bottomNavSafeExtra = 8;
  static const double navIconSize = 28;
  static const double navLabelFontSize = 9;
  static const double navIconLabelGap = 2;
  static const double navItemBottomPadding = 4;

  static const double liveIconSize = 28;
  static const double feedTopBarHeight = 44;
  static const double feedTopTabsTopPadding = 16;

  /// Gap between the feed top bar (Following / For You) and overlay content.
  static const double feedTopBarBottomGap = 12;
  static const double feedOverlayHorizontalPadding = 8;

  static const double addButtonWidth = 46;
  static const double addButtonHeight = 38;
  static const double addButtonRadius = 12;
  static const double addButtonIconSize = 28;
  static const double addButtonShadowBlur = 10;
  static const double addButtonShadowOffsetY = 4;

  static const double navBlurSigma = 10;
  static const double tabsBlurSigma = 12;

  static const double tabPillDividerWidth = 1;
  static const double tabPillDividerHeight = 14;
  static const double tabSelectedFontSize = 17;
  static const double tabUnselectedFontSize = 16;

  static const double progressBarPlayingHeight = 2.0;
  static const double progressBarMinHeight = 4;
  static const double progressBarScrubHeight = 6.0;

  /// Visible progress strip when stacked above the bottom nav (playhead may overflow).
  static const double feedStackedProgressLayoutHeight = progressBarMinHeight;

  /// Tall hit target so the bar is easy to grab for seeking.
  static const double progressBarHitHeight = 32.0;

  /// Extra lift above the bottom nav / comment bar (0 = flush).
  static const double progressBarBottomInset = 0.0;

  static const double progressBarHorizontalPadding = 12.0;

  /// Side inset for the progress line in the home feed search/progress stack.
  static const double progressBarFeedColumnHorizontalPadding = 9.0;
  static const double progressBarDotSize = 0.0;
  static const double progressBarDotScrubSize = 13.0;

  /// Extra caption/side-action inset for search pill + progress (excl. safe area).
  static const double feedVideoChromeAboveNav =
      feedSearchHintBarHeight +
      feedStackedProgressLayoutHeight +
      progressBarBottomInset;

  /// Matches [LiquidGlassBottomNav] vertical size (for overlay alignment).
  /// Uses [MediaQuery.viewPadding] so it stays correct when the scaffold body
  /// strips bottom padding ([extendBody]).
  static double homeBottomNavExtent(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    const tabLabelHeight = navLabelFontSize * 1.25;
    const tabColumnHeight = navIconSize + navIconLabelGap + tabLabelHeight;
    const centerSlotHeight = addButtonHeight + navItemBottomPadding;
    final rowHeight = tabColumnHeight > centerSlotHeight
        ? tabColumnHeight
        : centerSlotHeight;
    return bottomNavTopPadding + rowHeight + safeBottom + bottomNavSafeExtra;
  }

  /// Bottom inset for feed media/overlays when search is collapsed: matches the
  /// visible bottom app bar stack ([mainBottomNavHeight] + home indicator).
  static double homeFeedBottomBarReservedHeight(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final nav = homeBottomNavExtent(context);
    final design = mainBottomNavHeight + safeBottom;
    return nav > design ? nav : design;
  }

  /// Bottom of search/progress column — directly above bottom nav (matches profile viewer).
  static double feedVideoProgressBottomOffset(BuildContext context) {
    return homeBottomNavExtent(context) + progressBarBottomInset;
  }

  static const Duration videoProgressDuration = Duration(seconds: 15);

  static const int feedPageSize = 10;
  // Start loading the next page near the end so ±2 media preload stays fed.
  static const int feedPrefetchThresholdOffset = 2;
  static const int feedPrefetchMinPosts = 3;

  static const Duration tabRefreshTimeout = Duration(seconds: 30);
  static const double tabRefreshDisplacement = 40;
}
