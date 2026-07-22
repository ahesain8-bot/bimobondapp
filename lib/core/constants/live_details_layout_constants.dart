import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class LiveDetailsLayoutConstants {
  LiveDetailsLayoutConstants._();

  static const Color liveBadgeColor = Color(0xFFFE2C55);
  static const Color liveBadgeDark = Color(0xFFE02047);
  static const Color auctionActiveBadgeColor = Color(0xFF22C55E);
  static const Color auctionActiveBadgeDark = Color(0xFF16A34A);
  static const Color auctionFinishedBadgeColor = Color(0xFF9CA3AF);
  static const Color auctionFinishedBadgeDark = Color(0xFF6B7280);
  static const Color glassBorder = Colors.white24;
  static const Color glassFill = Color(0x1AFFFFFF);
  static const Color countdownBarFill = Color(0x14FFFFFF);
  static const Color countdownBarOverlay = Color(0x33000000);
  static const Color countdownBarBorder = Color(0x28FFFFFF);
  static const double countdownBarBlur = 12;
  static const double countdownBarRadius = 14;

  static const int initialHighestBid = 500000;
  static const int baseBidPerMessage = 1000;
  static const int mockChatCount = 30;
  static const int mockViewerCount = 1200;

  static const double headerAvatarRadius = 18;
  static const double headerGlassRadius = 30;
  static const double closeIconSize = 28;
  static const double liveBadgeLetterSpacing = 1.5;

  static const double chatAreaHeight = 250;
  static const double chatBubbleRadius = 16;
  static const double chatAvatarRadius = 9;
  static const double chatAvatarContentGap = 12;

  static const double inputHeight = 48;
  static const double inputRadius = 24;
  static const double actionButtonSize = 48;
  static const double quickBidRadius = 20;

  static const double topBidRadius = 30;
  static const double giftSheetRadius = 32;
  static const double giftSheetHeightFactor = 0.55;
  static const int giftGridCrossCount = 4;
  static const double giftGridAspectRatio = 0.62;
  static const double giftSheetBlur = 30;
  static const double giftTilePriceFontSize = 13;
  static const double giftFooterPriceFontSize = 24;
  static const double giftTilePriceLabelFontSize = 11;
  static const double giftFooterPriceLabelFontSize = 13;
  static const double giftTilePriceBoxHeight = 40;
  static const double giftFooterPriceBoxWidth = 200;
  static const double giftFooterPriceBoxHeight = 64;
  static const int giftNameMaxLength = 9;

  static const Color giftCommentGold = Color(0xFFFFD54F);
  static const Color giftCommentGoldDeep = Color(0xFFFFB300);
  static const Color giftCommentGoldText = Color(0xFFFFF8E1);

  static const double giftCommentFillOpacityDeep = 0.1;
  static const double giftCommentFillOpacityLight = 0.1;
  static const double giftCommentBorderOpacity = 0.3;
  static const double giftCommentGlowOpacity = 0.05;
  static const double giftCommentAvatarFillOpacity = 1;
  static const double giftCommentContentOpacity = 0.75;

  static const Duration pulseDuration = Duration(seconds: 1);
  static const Duration bidPopDuration = Duration(milliseconds: 300);
  static const Duration uiHideDuration = Duration(milliseconds: 300);

  static const double bidPopScaleEnd = 1.15;
  static const double pulseOpacityMin = 0.6;
  static const double pulseOpacityMax = 1.0;

  static const double uiSlideOffset = 1.0;
  static const double swipeVelocityThreshold = 500;

  static const List<int> quickBidAmounts = [1000, 5000, 10000, 50000];
  static const int mockCoinBalance = 1500;

  static const EdgeInsets screenHorizontalPadding = EdgeInsets.symmetric(
    horizontal: AppSizes.p16,
  );
  static const EdgeInsets inputPadding = EdgeInsets.fromLTRB(
    AppSizes.p16,
    AppSizes.p8,
    AppSizes.p16,
    AppSizes.p16,
  );

  static const double mediaPageDotSize = 6;
  static const double mediaPageDotActiveWidth = 18;
  static const double mediaPageIndicatorTopPadding = 4;
}
