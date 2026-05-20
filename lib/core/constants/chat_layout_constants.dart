import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class ChatLayoutConstants {
  ChatLayoutConstants._();

  // App bar
  static const double appBarHeight = 70;
  static const double appBarBlurSigma = 12;
  static const double appBarBackgroundAlpha = 0.8;
  static const double headerAvatarRadius = 18;
  static const double headerTitleFontSize = 15;
  static const double headerStatusFontSize = 10;
  static const double appBarLeadingIconSize = 20;
  static const double appBarActionIconSize = 22;
  static const double headerTitleLetterSpacing = -0.3;

  // Message list
  static const double messageListHorizontalPadding = AppSizes.p16;
  static const double messageListTopPadding = 0;
  static const double messageListBottomPadding = AppSizes.p20;
  static const double messageGroupTopSpacing = AppSizes.p16;
  static const double messageItemSpacing = AppSizes.p4;
  static const double senderHeaderHorizontalPadding = AppSizes.p12;
  static const double messageMaxWidthFactor = 0.75;
  static const double bubbleRadius = 20;
  static const double bubbleTailRadius = 4;
  static const double bubbleHorizontalPadding = AppSizes.p16;
  static const double bubbleVerticalPadding = 10;
  static const double bubbleShadowAlpha = 0.04;
  static const double bubbleShadowBlur = 10;
  static const Offset bubbleShadowOffset = Offset(0, 4);
  static const double sentGradientEndAlpha = 0.85;

  // Message content
  static const double imageMessageWidth = 200;
  static const double imageMessageHeight = 120;
  static const double replyPreviewRadius = 10;
  static const double replyPreviewBarWidth = 3;
  static const double replyPreviewBarHeight = 20;
  static const double replyPreviewFontSize = 11;
  static const double replyBarRadius = 15;
  static const double replyBarHorizontalPadding = AppSizes.p12;
  static const double replyBarVerticalPadding = AppSizes.p8;
  static const double replyBarIconSize = 16;
  static const double replyBarFontSize = 12;
  static const double reactionBadgeSize = 10;
  static const double reactionBadgePadding = 4;
  static const double reactionBadgeShadowBlur = 4;
  static const Offset reactionBadgeShadowOffset = Offset(0, 2);
  static const double reactionBadgeBorderAlpha = 0.2;
  static const double reactionBadgeShadowAlpha = 0.1;
  static const double statusIconSize = 12;
  static const double timeFontSize = 9;
  static const double messageFontSize = 14.5;
  static const double messageLineHeight = 1.4;
  static const double senderHeaderFontSize = 10;
  static const double senderHeaderPrimaryAlpha = 0.7;
  static const double footerHorizontalPadding = 4;
  static const double footerVerticalPadding = 2;
  static const double timeTextAlpha = 0.5;
  static const double reactionBadgeBottomOffset = -8;

  // Input bar
  static const double inputBarHorizontalPadding = AppSizes.p12;
  static const double inputBarTopPadding = AppSizes.p8;
  static const double inputBarBottomExtra = AppSizes.p12;
  static const double inputFieldHeight = 42;
  static const double inputFieldRadius = 22;
  static const double inputFieldFontSize = 15;
  static const double inputHintFontSize = 14;
  static const double inputHintAlpha = 0.3;
  static const double inputActionSize = 42;
  static const double inputFillAlpha = 0.05;
  static const double inputDividerAlpha = 0.05;
  static const double inputLeadingIconSize = 28;
  static const double inputLeadingIconAlpha = 0.6;
  static const double inputEmojiIconAlpha = 0.4;
  static const double inputSendIconSize = 20;
  static const double inputMicIconSize = 24;

  // Sheets
  static const double userInfoAvatarRadius = 40;
  static const double userInfoPadding = AppSizes.p24;
  static const double emojiSheetHeight = 350;
  static const double emojiSheetRadius = AppSizes.p24;
  static const double emojiSheetHandleWidth = 40;
  static const double emojiSheetHandleHeight = AppSizes.p4;
  static const double emojiSheetHandleRadius = 2;
  static const double emojiSheetHandleAlpha = 0.3;
  static const double emojiGridEmojiFontSize = 28;
  static const int emojiGridCrossCount = 7;
  static const int emojiGridItemCount = 42;
  static const double emojiGridSpacing = AppSizes.p12;
  static const double moreMenuRadius = AppSizes.p24;
  static const int moreMenuCrossCount = 4;
  static const double moreMenuMainSpacing = 20;
  static const double moreMenuIconSize = 54;
  static const double moreMenuIconRadius = AppSizes.p16;
  static const double moreMenuIconBackgroundAlpha = 0.1;
  static const double moreMenuItemIconSize = 28;
  static const double moreMenuLabelFontSize = 11;
  static const double reactionPickerMargin = AppSizes.p24;
  static const double reactionPickerRadius = 40;
  static const double reactionPickerVerticalPadding = AppSizes.p12;
  static const double reactionPickerHorizontalPadding = AppSizes.p20;
  static const double reactionEmojiSize = 26;

  // Recording overlay
  static const double recordingOverlayAlpha = 0.4;
  static const double recordingMicPadding = 32;
  static const double recordingMicSize = 64;
  static const double recordingShadowBlur = 20;
  static const double recordingTitleFontSize = 18;
  static const double recordingSubtitleFontSize = 14;
  static const int recordingWaveBarCount = 20;
  static const double recordingWaveBarWidth = 3;
  static const double recordingWaveBarMinHeight = 10;
  static const int recordingWaveBarMaxExtra = 30;
  static const double recordingWaveBarSpacing = 2;
  static const double recordingWaveBarRadius = 2;

  // Voice message
  static const double voiceMessageWidth = 200;
  static const double voicePlayIconSize = 28;
  static const int voiceWaveBarCount = 12;
  static const double voiceWaveBarWidth = 2;
  static const double voiceWaveBarMinHeight = 10;
  static const int voiceWaveBarMaxExtra = 15;
  static const double voiceWaveBarRadius = 1;
  static const double voiceDurationFontSize = 9;
  static const double voiceWavePrimaryAlpha = 0.3;
  static const double voiceWaveSentAlpha = 0.54;

  // Typing indicator
  static const double typingIndicatorTopPadding = AppSizes.p8;
  static const double typingIndicatorHorizontalPadding = 14;
  static const double typingIndicatorVerticalPadding = 10;
  static const double typingIndicatorRadius = 20;

  // Screen
  static const double errorBannerPadding = AppSizes.p8;
  static const double patternOpacityLight = 0.02;

  static const int chatMessageSkeletonCount = 6;
  static const double chatMessageSkeletonBubbleHeight = 44;
  static const double chatMessageSkeletonShortWidth = 140;
  static const double chatMessageSkeletonLongWidth = 220;

  static const Duration scrollAnimationDuration = Duration(milliseconds: 300);
  static const Duration mockTypingDelay = Duration(seconds: 1);
  static const Duration mockReplyDelay = Duration(seconds: 2);

  static const List<String> reactionEmojis = [
    '❤️',
    '👍',
    '😂',
    '😮',
    '😢',
    '🔥',
  ];

  static const List<String> pickerEmojis = [
    '❤️',
    '🙌',
    '🔥',
    '😂',
    '😍',
    '✨',
    '🥺',
    '👏',
    '💯',
    '🙏',
    '🤯',
    '😭',
    '😎',
    '🥳',
    '😉',
    '🥰',
    '🤔',
    '👍',
    '👌',
    '👀',
  ];
}
