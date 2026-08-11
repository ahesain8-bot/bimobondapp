import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:flutter/material.dart';

/// Shared layout tokens for [VideoPostWidget] chrome.
abstract final class VideoPostLayoutConstants {
  static const double actionIconSize = 32;
  static const double actionLabelSize = 10;
  static const double actionSpacing = 14;
  static const double actionHitWidth = 48;
  static const double actionColumnInset = 8;
  static const double contentActionGap = 12;
  static const double contentActionSidePadding =
      actionColumnInset + actionHitWidth + contentActionGap;
  static const double contentEdgeInset = 16;
  static const double profileAvatarRadius = 24;
  static const double musicDiscSize = 40;

  /// Responsive vertical spacing between side action buttons.
  static double responsiveActionSpacing(BuildContext context) {
    final scale = HomeLayoutConstants.heightScale(context, minScale: 0.65, maxScale: 1.15);
    return (actionSpacing * scale).clamp(7.0, 16.0);
  }

  /// Responsive vertical gap between avatar and like button.
  static double responsiveAvatarGap(BuildContext context) {
    final scale = HomeLayoutConstants.heightScale(context, minScale: 0.65, maxScale: 1.15);
    return (22.0 * scale).clamp(10.0, 24.0);
  }

  /// Responsive content side padding (left edge inset).
  static double responsiveContentEdgeInset(BuildContext context) {
    final scale = HomeLayoutConstants.widthScale(context, minScale: 0.85, maxScale: 1.15);
    return (contentEdgeInset * scale).clamp(12.0, 20.0);
  }

  /// Responsive content right padding (avoiding side action buttons).
  static double responsiveContentActionSidePadding(BuildContext context) {
    final widthScale = HomeLayoutConstants.widthScale(context, minScale: 0.85, maxScale: 1.15);
    return ((actionColumnInset + actionHitWidth + contentActionGap) * widthScale).clamp(52.0, 76.0);
  }

  static const Color tikTokLikeRed = Color(0xFFFE2C55);
  static const Color tikTokSaveYellow = Color(0xFFFACC15);
  static const List<Shadow> actionTextShadow = [
    Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1)),
  ];
}
