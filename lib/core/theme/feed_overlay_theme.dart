import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Immersive feed overlay colors (home video feed + bottom nav on home).
@immutable
class FeedOverlayTheme extends ThemeExtension<FeedOverlayTheme> {
  final Color feedBackground;
  final Color overlayForeground;
  final Color overlayForegroundMuted;
  final Color navBarScrim;
  final Color tabPillFill;
  final Color tabPillBorder;
  final Color tabDivider;
  final Color progressTrack;
  final Color progressFill;
  final Color shadow;

  const FeedOverlayTheme({
    required this.feedBackground,
    required this.overlayForeground,
    required this.overlayForegroundMuted,
    required this.navBarScrim,
    required this.tabPillFill,
    required this.tabPillBorder,
    required this.tabDivider,
    required this.progressTrack,
    required this.progressFill,
    required this.shadow,
  });

  static FeedOverlayTheme forBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final mutedAlpha = isDark ? 0.6 : 0.65;

    return FeedOverlayTheme(
      feedBackground: isDark ? const Color(0xFF000000) : Colors.black,
      overlayForeground: Colors.white,
      overlayForegroundMuted: Colors.white.withValues(alpha: mutedAlpha),
      navBarScrim: Colors.black.withValues(alpha: 0.2),
      tabPillFill: Colors.white.withValues(alpha: 0.12),
      tabPillBorder: Colors.white.withValues(alpha: 0.2),
      tabDivider: Colors.white.withValues(alpha: 0.3),
      progressTrack: Colors.white.withValues(alpha: 0.1),
      progressFill: AppTheme.primaryColor,
      shadow: Colors.black.withValues(alpha: 0.45),
    );
  }

  static FeedOverlayTheme of(BuildContext context) {
    return Theme.of(context).extension<FeedOverlayTheme>()!;
  }

  @override
  FeedOverlayTheme copyWith({
    Color? feedBackground,
    Color? overlayForeground,
    Color? overlayForegroundMuted,
    Color? navBarScrim,
    Color? tabPillFill,
    Color? tabPillBorder,
    Color? tabDivider,
    Color? progressTrack,
    Color? progressFill,
    Color? shadow,
  }) {
    return FeedOverlayTheme(
      feedBackground: feedBackground ?? this.feedBackground,
      overlayForeground: overlayForeground ?? this.overlayForeground,
      overlayForegroundMuted:
          overlayForegroundMuted ?? this.overlayForegroundMuted,
      navBarScrim: navBarScrim ?? this.navBarScrim,
      tabPillFill: tabPillFill ?? this.tabPillFill,
      tabPillBorder: tabPillBorder ?? this.tabPillBorder,
      tabDivider: tabDivider ?? this.tabDivider,
      progressTrack: progressTrack ?? this.progressTrack,
      progressFill: progressFill ?? this.progressFill,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  FeedOverlayTheme lerp(ThemeExtension<FeedOverlayTheme>? other, double t) {
    if (other is! FeedOverlayTheme) return this;
    return FeedOverlayTheme(
      feedBackground: Color.lerp(feedBackground, other.feedBackground, t)!,
      overlayForeground:
          Color.lerp(overlayForeground, other.overlayForeground, t)!,
      overlayForegroundMuted: Color.lerp(
        overlayForegroundMuted,
        other.overlayForegroundMuted,
        t,
      )!,
      navBarScrim: Color.lerp(navBarScrim, other.navBarScrim, t)!,
      tabPillFill: Color.lerp(tabPillFill, other.tabPillFill, t)!,
      tabPillBorder: Color.lerp(tabPillBorder, other.tabPillBorder, t)!,
      tabDivider: Color.lerp(tabDivider, other.tabDivider, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      progressFill: Color.lerp(progressFill, other.progressFill, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
