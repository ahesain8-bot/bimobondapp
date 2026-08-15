import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Colors.blue;
  static const Color secondary = Colors.orange;
  static const Color backgroundLight = Colors.white;
  static const Color backgroundDark = Color(0xFF121212);
  static const Color error = Colors.redAccent;
  static const Color textPrimaryLight = Colors.black87;
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondary = Color(0xFF8E8E8E);

  /// LIVE start button background.
  static const Color primaryRed = Color(0xFFEF4B5B);

  /// Live container background.
  static const Color liveContainer = Color(0xFF2D4A35);

  /// Guests avatar gradient start.
  static const Color avatarGradientStart = Color(0xFF6B4A38);

  /// Guests avatar gradient end.
  static const Color avatarGradientEnd = Color(0xFF272A30);

  /// Guests avatar icon color.
  static const Color avatarIcon = Color(0xFFE9B99F);

  // ── Live room overlays ────────────────────────────────────────────────
  /// Semi-transparent pill / chip background over video.
  static const Color overlayPill = Color(0x8A000000);

  /// Softer overlay used for smaller chips.
  static const Color overlayPillSoft = Color(0x59000000);

  /// Bottom action bar fill.
  static const Color bottomBar = Color(0xE6101010);

  /// Orange heart / like accent.
  static const Color heartOrange = Color(0xFFFF6A3D);

  /// Hourly ranking flame accent.
  static const Color flameYellow = Color(0xFFFFC107);

  /// Guest invite / add pill.
  static const Color inviteGreen = Color(0xFF2EBD59);

  /// Multi-guest / collab pink ring.
  static const Color collabPink = Color(0xFFFF5A8A);

  /// Multi-guest / collab blue ring.
  static const Color collabBlue = Color(0xFF4DA3FF);

  /// Bottom viewers / group icon.
  static const Color viewersRed = Color(0xFFE53935);

  /// Host avatar placeholder gradient (green landscape).
  static const Color hostAvatarStart = Color(0xFF4A7C59);

  /// Host avatar placeholder gradient end.
  static const Color hostAvatarEnd = Color(0xFF2D4A35);

  // ── Live effects ──────────────────────────────────────────────────────
  /// Effects tray / panel fill.
  static const Color effectsPanel = Color(0xF2101010);

  /// Effects info pill fill.
  static const Color effectsInfoPill = Color(0xCC2A2A2A);

  /// Effects category inactive label.
  static const Color effectsTabInactive = Color(0xFFBDBDBD);

  // ── Live room options menu ────────────────────────────────────────────
  /// Sheet / card stack background behind option cards.
  static const Color optionsSheetBackground = Color(0xFFF2F2F2);

  /// Options menu card fill.
  static const Color optionsCard = Colors.white;

  /// Options primary label / icon.
  static const Color optionsForeground = Color(0xFF161616);

  /// Options secondary / subtitle text.
  static const Color optionsSubtitle = Color(0xFF8E8E8E);

  /// Active toggle track (teal).
  static const Color optionsToggleActive = Color(0xFF26D3B4);

  /// Inactive toggle track.
  static const Color optionsToggleInactive = Color(0xFFE5E5EA);

  /// Notification badge on option rows.
  static const Color optionsBadge = Color(0xFFFF3B30);

  /// Dimmed scrim behind the options sheet.
  static const Color optionsScrim = Color(0x99000000);

  // ── Live share sheet ──────────────────────────────────────────────────
  /// Share sheet surface.
  static const Color shareSheetBackground = Colors.white;

  /// Share sheet primary text / icons.
  static const Color shareForeground = Color(0xFF161616);

  /// Share sheet secondary labels.
  static const Color shareLabel = Color(0xFF3A3A3A);

  /// Share sheet hairline dividers.
  static const Color shareDivider = Color(0xFFE8E8E8);

  /// Dimmed contact avatar placeholder.
  static const Color shareAvatarPlaceholder = Color(0xFFE0E0E0);

  /// Muted action circle (story / feedback).
  static const Color shareActionCircle = Color(0xFFF0F0F0);

  /// Disabled promote control.
  static const Color shareDisabled = Color(0xFFC8C8C8);

  /// Scrim behind the share sheet.
  static const Color shareScrim = Color(0x99000000);

  /// WhatsApp brand green.
  static const Color shareWhatsApp = Color(0xFF25D366);

  /// Telegram brand blue.
  static const Color shareTelegram = Color(0xFF2AABEE);

  /// Facebook brand blue.
  static const Color shareFacebook = Color(0xFF1877F2);

  /// Copy-link circle blue.
  static const Color shareCopyLink = Color(0xFF2B7CFF);
}
