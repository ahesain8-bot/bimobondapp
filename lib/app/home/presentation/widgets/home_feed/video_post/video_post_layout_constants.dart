import 'package:flutter/material.dart';

/// Shared layout tokens for [VideoPostWidget] chrome.
abstract final class VideoPostLayoutConstants {
  static const double actionIconSize = 35;
  static const double actionLabelSize = 12;
  static const double actionSpacing = 20;
  static const double actionHitWidth = 48;
  static const double actionColumnInset = 8;
  static const double contentActionGap = 12;
  static const double contentActionSidePadding =
      actionColumnInset + actionHitWidth + contentActionGap;
  static const double contentEdgeInset = 16;
  static const double profileAvatarRadius = 24;
  static const double musicDiscSize = 40;
  static const Color tikTokLikeRed = Color(0xFFFE2C55);
  static const Color tikTokSaveYellow = Color(0xFFFACC15);
  static const List<Shadow> actionTextShadow = [
    Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1)),
  ];
}
