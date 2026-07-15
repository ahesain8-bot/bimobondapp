import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Semantic colors for the chat screen (bubbles, input, overlays, sheets).
@immutable
class ChatTheme extends ThemeExtension<ChatTheme> {
  final Color activeStatus;
  final Color readReceipt;
  final Color replyAccent;
  final Color onSentBubble;
  final Color onSentBubbleMuted;
  final Color receivedBubbleColor;
  final Color onReceivedBubble;
  final Color onReceivedBubbleMuted;
  final Color sentBubbleColor;
  final Color inputFill;
  final Color recordingScrim;
  final Color recordingForeground;
  final Color recordingForegroundMuted;
  final Color waveformOnOverlay;
  final Color bubbleShadow;
  final Color pendingReceipt;
  final Color backgroundGradientEnd;
  final Color chatBackgroundColor;
  final Color sentBubbleGradientStart;
  final Color sentBubbleGradientEnd;
  final List<Color> moreMenuIconColors;

  /// TikTok-style inbox search field fill.
  final Color inboxSearchFill;

  /// Secondary / muted text on inbox & chat headers.
  final Color inboxSecondaryText;

  /// Trailing chevron / icons on inbox rows.
  final Color inboxChevron;

  /// Composer send button when idle (no text).
  final Color sendIdleFill;

  const ChatTheme({
    required this.activeStatus,
    required this.readReceipt,
    required this.replyAccent,
    required this.onSentBubble,
    required this.onSentBubbleMuted,
    required this.receivedBubbleColor,
    required this.onReceivedBubble,
    required this.onReceivedBubbleMuted,
    required this.sentBubbleColor,
    required this.inputFill,
    required this.recordingScrim,
    required this.recordingForeground,
    required this.recordingForegroundMuted,
    required this.waveformOnOverlay,
    required this.bubbleShadow,
    required this.pendingReceipt,
    required this.backgroundGradientEnd,
    required this.chatBackgroundColor,
    required this.sentBubbleGradientStart,
    required this.sentBubbleGradientEnd,
    required this.moreMenuIconColors,
    required this.inboxSearchFill,
    required this.inboxSecondaryText,
    required this.inboxChevron,
    required this.sendIdleFill,
  });

  static ChatTheme forBrightness(Brightness brightness, ColorScheme scheme) {
    final isDark = brightness == Brightness.dark;

    return ChatTheme(
      activeStatus: AppTheme.successAccent,
      readReceipt: Colors.green,
      replyAccent: scheme.primary,
      onSentBubble: scheme.onSurface,
      onSentBubbleMuted: scheme.onSurface.withValues(alpha: 0.6),
      receivedBubbleColor: scheme.primary,
      onReceivedBubble: Colors.white,
      onReceivedBubbleMuted: Colors.white.withValues(alpha: 0.7),
      sentBubbleColor: isDark ? scheme.surface : Colors.white,
      inputFill: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      recordingScrim: Colors.black.withValues(
        alpha: ChatLayoutConstants.recordingOverlayAlpha,
      ),
      recordingForeground: Colors.white,
      recordingForegroundMuted: Colors.white.withValues(alpha: 0.7),
      waveformOnOverlay: Colors.white.withValues(alpha: 0.8),
      bubbleShadow: Colors.black.withValues(
        alpha: ChatLayoutConstants.bubbleShadowAlpha,
      ),
      pendingReceipt: scheme.onSurface.withValues(alpha: 0.5),
      backgroundGradientEnd: isDark
          ? scheme.surface.withValues(alpha: 0.35)
          : scheme.primary.withValues(
              alpha: ChatLayoutConstants.patternOpacityLight,
            ),
      chatBackgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      sentBubbleGradientStart: scheme.primary.withValues(
        alpha: ChatLayoutConstants.sentBubbleOpacity,
      ),
      sentBubbleGradientEnd: scheme.primary.withValues(
        alpha: ChatLayoutConstants.sentBubbleOpacity,
      ),
      moreMenuIconColors: const [
        Color(0xFF2196F3),
        Color(0xFFFF9800),
        Color(0xFFF44336),
        Color(0xFF4CAF50),
        Color(0xFF9C27B0),
        Color(0xFF00BCD4),
        Color(0xFFE91E63),
        Color(0xFF3F51B5),
      ],
      inboxSearchFill: isDark
          ? const Color(0xFF2C2C2C)
          : const Color(0xFFF1F1F2),
      inboxSecondaryText: scheme.onSurface.withValues(alpha: 0.45),
      inboxChevron: scheme.onSurface.withValues(alpha: 0.28),
      sendIdleFill: isDark
          ? scheme.onSurface.withValues(alpha: 0.2)
          : const Color(0xFFE8E8E8),
    );
  }

  static ChatTheme of(BuildContext context) {
    return Theme.of(context).extension<ChatTheme>()!;
  }

  @override
  ChatTheme copyWith({
    Color? activeStatus,
    Color? readReceipt,
    Color? replyAccent,
    Color? onSentBubble,
    Color? onSentBubbleMuted,
    Color? receivedBubbleColor,
    Color? onReceivedBubble,
    Color? onReceivedBubbleMuted,
    Color? sentBubbleColor,
    Color? inputFill,
    Color? recordingScrim,
    Color? recordingForeground,
    Color? recordingForegroundMuted,
    Color? waveformOnOverlay,
    Color? bubbleShadow,
    Color? pendingReceipt,
    Color? backgroundGradientEnd,
    Color? chatBackgroundColor,
    Color? sentBubbleGradientStart,
    Color? sentBubbleGradientEnd,
    List<Color>? moreMenuIconColors,
    Color? inboxSearchFill,
    Color? inboxSecondaryText,
    Color? inboxChevron,
    Color? sendIdleFill,
  }) {
    return ChatTheme(
      activeStatus: activeStatus ?? this.activeStatus,
      readReceipt: readReceipt ?? this.readReceipt,
      replyAccent: replyAccent ?? this.replyAccent,
      onSentBubble: onSentBubble ?? this.onSentBubble,
      onSentBubbleMuted: onSentBubbleMuted ?? this.onSentBubbleMuted,
      receivedBubbleColor: receivedBubbleColor ?? this.receivedBubbleColor,
      onReceivedBubble: onReceivedBubble ?? this.onReceivedBubble,
      onReceivedBubbleMuted:
          onReceivedBubbleMuted ?? this.onReceivedBubbleMuted,
      sentBubbleColor: sentBubbleColor ?? this.sentBubbleColor,
      inputFill: inputFill ?? this.inputFill,
      recordingScrim: recordingScrim ?? this.recordingScrim,
      recordingForeground: recordingForeground ?? this.recordingForeground,
      recordingForegroundMuted:
          recordingForegroundMuted ?? this.recordingForegroundMuted,
      waveformOnOverlay: waveformOnOverlay ?? this.waveformOnOverlay,
      bubbleShadow: bubbleShadow ?? this.bubbleShadow,
      pendingReceipt: pendingReceipt ?? this.pendingReceipt,
      backgroundGradientEnd:
          backgroundGradientEnd ?? this.backgroundGradientEnd,
      chatBackgroundColor: chatBackgroundColor ?? this.chatBackgroundColor,
      sentBubbleGradientStart:
          sentBubbleGradientStart ?? this.sentBubbleGradientStart,
      sentBubbleGradientEnd:
          sentBubbleGradientEnd ?? this.sentBubbleGradientEnd,
      moreMenuIconColors: moreMenuIconColors ?? this.moreMenuIconColors,
      inboxSearchFill: inboxSearchFill ?? this.inboxSearchFill,
      inboxSecondaryText: inboxSecondaryText ?? this.inboxSecondaryText,
      inboxChevron: inboxChevron ?? this.inboxChevron,
      sendIdleFill: sendIdleFill ?? this.sendIdleFill,
    );
  }

  @override
  ChatTheme lerp(ThemeExtension<ChatTheme>? other, double t) {
    if (other is! ChatTheme) return this;
    return ChatTheme(
      activeStatus: Color.lerp(activeStatus, other.activeStatus, t)!,
      readReceipt: Color.lerp(readReceipt, other.readReceipt, t)!,
      replyAccent: Color.lerp(replyAccent, other.replyAccent, t)!,
      onSentBubble: Color.lerp(onSentBubble, other.onSentBubble, t)!,
      onSentBubbleMuted: Color.lerp(
        onSentBubbleMuted,
        other.onSentBubbleMuted,
        t,
      )!,
      receivedBubbleColor: Color.lerp(
        receivedBubbleColor,
        other.receivedBubbleColor,
        t,
      )!,
      onReceivedBubble: Color.lerp(
        onReceivedBubble,
        other.onReceivedBubble,
        t,
      )!,
      onReceivedBubbleMuted: Color.lerp(
        onReceivedBubbleMuted,
        other.onReceivedBubbleMuted,
        t,
      )!,
      sentBubbleColor: Color.lerp(sentBubbleColor, other.sentBubbleColor, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      recordingScrim: Color.lerp(recordingScrim, other.recordingScrim, t)!,
      recordingForeground: Color.lerp(
        recordingForeground,
        other.recordingForeground,
        t,
      )!,
      recordingForegroundMuted: Color.lerp(
        recordingForegroundMuted,
        other.recordingForegroundMuted,
        t,
      )!,
      waveformOnOverlay: Color.lerp(
        waveformOnOverlay,
        other.waveformOnOverlay,
        t,
      )!,
      bubbleShadow: Color.lerp(bubbleShadow, other.bubbleShadow, t)!,
      pendingReceipt: Color.lerp(pendingReceipt, other.pendingReceipt, t)!,
      backgroundGradientEnd: Color.lerp(
        backgroundGradientEnd,
        other.backgroundGradientEnd,
        t,
      )!,
      chatBackgroundColor: Color.lerp(
        chatBackgroundColor,
        other.chatBackgroundColor,
        t,
      )!,
      sentBubbleGradientStart: Color.lerp(
        sentBubbleGradientStart,
        other.sentBubbleGradientStart,
        t,
      )!,
      sentBubbleGradientEnd: Color.lerp(
        sentBubbleGradientEnd,
        other.sentBubbleGradientEnd,
        t,
      )!,
      moreMenuIconColors: other.moreMenuIconColors,
      inboxSearchFill: Color.lerp(inboxSearchFill, other.inboxSearchFill, t)!,
      inboxSecondaryText: Color.lerp(
        inboxSecondaryText,
        other.inboxSecondaryText,
        t,
      )!,
      inboxChevron: Color.lerp(inboxChevron, other.inboxChevron, t)!,
      sendIdleFill: Color.lerp(sendIdleFill, other.sendIdleFill, t)!,
    );
  }
}
