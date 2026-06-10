import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class MessagesLayoutConstants {
  MessagesLayoutConstants._();

  static const double appBarHeight = 70;
  static const double appBarBlurSigma = 12;
  static const double appBarBackgroundAlpha = 0.7;
  static const double inboxTitleFontSize = 20;
  static const double inboxChipRadius = 20;
  static const double inboxChipAlpha = 0.05;

  static const double refreshEdgeOffset = 100;
  static const Duration refreshDelay = Duration(seconds: 1);

  static const double searchBarHeight = 48;
  static const double searchBarTopPadding = AppSizes.p8;
  static const double searchBarBottomPadding = AppSizes.p8;
  static const double searchBarRadius = 16;
  static const double searchBarShadowAlpha = 0.03;
  static const double searchBarBorderAlpha = 0.05;
  static const double searchIconAlpha = 0.5;

  static const double activeUsersBarHeight = 100;
  static const double activeStorySize = 64;
  static const double activeAvatarRadius = 26;
  static const double activeRingWidth = 2.5;
  static const double activeDotSize = 14;
  static const Color activeDotColor = Colors.green;

  static const double activitySectionHeight = 120;
  static const double activityIconSize = 56;
  static const double activityIconRadius = 18;
  static const double activityItemSpacing = 20;
  static const Color activityFollowersColor = Color(0xFF007AFF);
  static const Color activityLikesColor = Color(0xFFFF2D55);
  static const Color activityCommentsColor = Color(0xFF34C759);
  static const Color activityMentionsColor = Color(0xFFAF52DE);
  static const Color activityNotificationsColor = Color(0xFFFF9500);
  static const Color activityBadgeColor = Color(0xFFFF3B30);

  static const double suggestionsStripHeight = 220;
  static const double suggestionCardWidth = 150;
  static const double suggestionCardRadius = 24;
  static const double suggestionAvatarRadius = 30;
  static const double suggestionFollowButtonHeight = 32;

  static const double mentionsStripHeight = 70;
  static const double mentionCardWidth = 220;
  static const double mentionCardRadius = 16;
  static const double mentionAvatarRadius = 20;
  static const double mentionPreviewSize = 36;

  static const double sectionHeaderFontSize = 18;
  static const double sectionLinkFontSize = 13;
  static const double conversationAvatarRadius = 28;
  static const double conversationTileRadius = 20;
  static const double conversationUnreadAlpha = 0.03;
  static const double conversationUnreadDotSize = 8;
  static const double emptyStateHeight = 230;
  static const int recentMessagesPreviewCount = 2;
  static const int recentMentionsPreviewCount = 5;
  static const int chatListSkeletonItemCount = 6;
  static const double chatListSkeletonTileHeight = 72;

  static const double glassButtonAlpha = 0.08;
  static const double dividerAlpha = 0.05;
  static const double bottomSpacer = 60;

  static const double horizontalPadding = AppSizes.p16;
  static const double sectionHorizontalPadding = 20;
}
