import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

/// Central text styles used across the whole app.
class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle titleMedium = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodySmall = TextStyle(
    color: Colors.white70,
    fontSize: 12,
  );

  /// Tool button label (single line, may shrink via FittedBox).
  static const TextStyle toolLabel = TextStyle(
    color: Colors.white,
    fontSize: 12,
    height: 1.05,
    fontWeight: FontWeight.w400,
  );

  /// Live rewards status pill label.
  static const TextStyle statusRewardLabel = TextStyle(
    color: Color(0xFFE3E3E3),
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  /// Progress hint label below the status bar.
  static const TextStyle progressHintLabel = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// Live title hint.
  static const TextStyle titleHint = TextStyle(
    color: Colors.white70,
    fontSize: 16,
  );

  /// Live title input.
  static const TextStyle titleInput = TextStyle(
    color: Colors.white,
    fontSize: 16,
  );

  /// LIVE start button title.
  static const TextStyle liveTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  /// LIVE start button action.
  static const TextStyle liveStart = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Options row text.
  static const TextStyle option = TextStyle(
    color: Colors.white,
    fontSize: 12,
  );

  /// Bottom tab text.
  static const TextStyle tab = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  /// Active bottom tab text.
  static const TextStyle tabActive = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.bold,
  );

  // ── Live room ─────────────────────────────────────────────────────────
  /// Host display name in the profile pill.
  static const TextStyle roomHostName = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  /// Small counters inside overlay pills.
  static const TextStyle roomCounter = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  /// Ranking / gallery / invite chip label.
  static const TextStyle roomChip = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.1,
  );

  /// Live-room system / chat feed text.
  static const TextStyle roomChat = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    shadows: [
      Shadow(
        color: Color(0x99000000),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
  );

  // ── Live effects ──────────────────────────────────────────────────────
  /// Effects info pill label.
  static const TextStyle effectsInfo = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Effects category tab label.
  static const TextStyle effectsTab = TextStyle(
    color: AppColors.effectsTabInactive,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Active effects category tab label.
  static const TextStyle effectsTabActive = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // ── Live room options menu ────────────────────────────────────────────
  /// Options menu primary row title.
  static const TextStyle optionsMenuTitle = TextStyle(
    color: AppColors.optionsForeground,
    fontSize: AppSizes.fontSizeOptionsTitle,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  /// Options menu secondary description.
  static const TextStyle optionsMenuSubtitle = TextStyle(
    color: AppColors.optionsSubtitle,
    fontSize: AppSizes.fontSizeOptionsSubtitle,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Options menu footer / help link.
  static const TextStyle optionsMenuFooter = TextStyle(
    color: AppColors.optionsSubtitle,
    fontSize: AppSizes.fontSizeOptionsSubtitle,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // ── Live share sheet ──────────────────────────────────────────────────
  /// Share sheet centered title.
  static const TextStyle shareTitle = TextStyle(
    color: AppColors.shareForeground,
    fontSize: AppSizes.fontSizeShareTitle,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Label under a share contact / channel circle.
  static const TextStyle shareItemLabel = TextStyle(
    color: AppColors.shareLabel,
    fontSize: AppSizes.fontSizeShareLabel,
    fontWeight: FontWeight.w400,
    height: 1.15,
  );
}
