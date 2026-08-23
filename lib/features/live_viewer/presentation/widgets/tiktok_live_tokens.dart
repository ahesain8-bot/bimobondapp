import 'package:flutter/material.dart';

/// Pixel-measured TikTok LIVE viewer tokens (~390pt iPhone reference).
/// Source of truth: real TikTok LIVE chrome — do not use Material defaults.
abstract final class TikTokLiveTokens {
  // —— Brand ——
  static const Color liveRed = Color(0xFFFE2C55);
  static const Color liveCyan = Color(0xFF25F4EE);
  static const Color followRed = Color(0xFFFE2C55);
  static const Color hostTagOrange = Color(0xFFFF8A00);
  static const Color joinGold = Color(0xFFFFCC33);
  static const Color giftPink = Color(0xFFFF2D55);

  // —— Frost / glass ——
  static Color frost([double a = 0.40]) => Color.fromRGBO(0, 0, 0, a);
  static Color frostLight([double a = 0.14]) =>
      Color.fromRGBO(255, 255, 255, a);
  static Color badgeBg([double a = 0.38]) => Color.fromRGBO(0, 0, 0, a);

  // —— Top bar ——
  static const double topInsetH = 10;
  static const double topInsetV = 6;
  static const double topRowGap = 7;
  static const double hostPillH = 40;
  static const double hostPillR = 20;
  static const double hostAvatar = 32;
  static const double hostAvatarGap = 5;
  static const double followH = 26;
  static const double followR = 13;
  static const double viewerAvatar = 22;
  static const double viewerOverlap = 7; // center pitch = 15
  static const double viewerBorder = 1.5;
  static const double closeIcon = 36;

  /// Black gap between badge row and PK score bar (reference green marks).
  static const double badgeGapBelow = 12;

  /// Black gap between badge row and multi-guest grid (reference — wider).
  static const double multiGridChromeGap = 20;
  static const double badgeH = 20; // matches _Pill height in chrome
  /// Top chrome body under status bar: pad + host row + gap + badges.
  static const double topChromeBodyH =
      2 + hostPillH + 6 + badgeH; // matches TikTokLiveTopBar
  static const double badgeR = 11;
  static const double badgeGap = 5;
  static const double badgePadH = 8;

  // —— Bottom bar ——
  static const double bottomInsetH = 10;
  static const double bottomInsetV = 8;
  static const double bottomGap = 8;
  static const double bottomIconGap = 7;
  static const double emojiSize = 38;
  static const double inputH = 38;
  static const double inputR = 19;
  static const double shareIcon = 27;
  static const double giftIcon = 30;
  static const double roseIcon = 36;
  static const double guestIcon = 28;
  static const double treasureFloat = 44;

  // —— Comments ——
  static const double commentMaxWidthFactor = 0.76;
  static const double commentLeft = 12;
  static const double commentAboveBar = 10;
  static const double commentAvatar = 24;
  static const double commentAvatarGap = 6;
  static const double commentGap = 5;
  static const double commentFade = 36;
  static const double commentFeedH = 216;

  // —— Gift toast ——
  static const double toastTopFromSafe = 130;
  static const double toastLeft = 8;
  static const double toastH = 44;
  static const double toastR = 22;
  static const double toastAvatar = 32;
  static const double toastGiftIcon = 30;
  static const double comboFont = 30;

  // —— Hearts ——
  static const double heartMin = 24;
  static const double heartMax = 40;
  static const double heartRise = 260;
  static const int heartMsMin = 1600;
  static const int heartMsMax = 2600;

  // —— Scrims ——
  static const double topScrimH = 132;
  static const double topScrimAlpha = 0.52;

  /// Bottom comment-zone scrim (reference: soft fade over video).
  static const double bottomScrimH = 320;
  static const double bottomScrimAlpha = 0.94;

  /// PK: comment overlay height; video extends under it with gradient.
  static const double pkCommentBandH = 168;
  static const double pkContributorOverlap = 52;

  /// PK video top offset below status bar (under badge row; reference match).
  static const double pkVideoTopBelowSafe = 84;

  /// Combined PK split aspect (width / height). Higher = shorter letterboxed band.
  /// Tuned to TikTok LIVE PK middle-band framing (~middle third of screen).
  static const double pkVideoAspect = 1.35;

  /// Extra black gap below PK video before comment band.
  static const double pkVideoBottomGap = 8;

  // —— Type ——
  static const TextStyle hostName = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.05,
    letterSpacing: -0.1,
  );

  static const TextStyle likeCount = TextStyle(
    color: Color(0xB3FFFFFF), // 0.70
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.1,
  );

  static const TextStyle follow = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const TextStyle viewerCount = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1,
  );

  static const TextStyle badge = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  static const TextStyle inputHint = TextStyle(
    color: Color(0x99FFFFFF), // 0.60
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static const TextStyle commentUser = TextStyle(
    color: Color(0xE6FFFFFF), // 0.90
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );

  static const TextStyle commentBody = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.25,
    shadows: [
      Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 0.5)),
    ],
  );

  static const TextStyle joinUser = TextStyle(
    color: joinGold,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );
}
