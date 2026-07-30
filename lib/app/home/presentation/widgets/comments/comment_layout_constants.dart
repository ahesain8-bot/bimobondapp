import 'package:flutter/material.dart';

class CommentLayout {
  CommentLayout._();

  static const double avatarRadius = 18;
  static const double replyAvatarRadius = 16;
  static const double avatarSize = avatarRadius * 2;
  static const double threadIndent = 18;

  /// Comment list typography & spacing (compact / TikTok-like).
  static const double usernameFontSize = 12;
  static const double bodyFontSize = 13;
  static const double metaFontSize = 11;
  static const double threadActionFontSize = 12;
  static const double bodyLineHeight = 1.25;
  static const double avatarTextGap = 8;
  static const double gapAfterUsername = 2;
  static const double gapBeforeMeta = 4;
  static const double gapBeforeTranslate = 4;
  static const double itemBottomSpacing = 10;
  static const double replyTopSpacing = 8;
  static const double metaActionGap = 10;

  /// Post likes tab in engagement sheet (name only, compact).
  static const double likesAvatarRadius = 22;
  static const double likesNameFontSize = 15;
  static const double likesListHorizontalPadding = 12;
  static const double likesRowSpacing = 2;

  /// TikTok-style comment composer (light mode reference).
  static const Color composerFieldFillLight = Color(0xFFF1F1F2);
  static const Color composerFooterDividerLight = Color(0xFFECECEC);
  static const Color composerHintLight = Color(0xFF8A8A8E);

  static const double composerAvatarRadius = 16;
  static const double composerFieldMinHeight = 38;
  static const double composerFieldRadius = 19;
  static const double composerFontSize = 15;
  static const double composerEmojiSize = 22;
}
