import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum CallUiStatusState {
  calling,
  ringing,
  connecting,
  connected,
  reconnecting,
  poorConnection,
  cameraDisabled,
  microphoneMuted,
  callEnded,
  userDeclined,
  userUnavailable,
}

class CallStatusBadge extends StatelessWidget {
  final CallUiStatusState status;
  final String? timerText;
  final bool isDark;

  const CallStatusBadge({
    super.key,
    required this.status,
    this.timerText,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = isDark || theme.brightness == Brightness.dark;

    final bgColor = _getBackgroundColor(isDarkTheme);
    final borderColor = _getBorderColor(isDarkTheme);
    final textColor = _getTextColor(isDarkTheme);
    final iconData = _getIconData();
    final iconColor = _getIconColor();
    final textStr = _getStatusString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == CallUiStatusState.connected) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981), // Emerald green pulse
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timerText ?? '00:00',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ] else ...[
            if (iconData != null) ...[
              Icon(iconData, color: iconColor, size: 14),
              const SizedBox(width: 6),
            ] else ...[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              textStr,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusString() {
    switch (status) {
      case CallUiStatusState.calling:
        return 'Calling...';
      case CallUiStatusState.ringing:
        return 'Ringing...';
      case CallUiStatusState.connecting:
        return 'Connecting...';
      case CallUiStatusState.connected:
        return timerText ?? '00:00';
      case CallUiStatusState.reconnecting:
        return 'Reconnecting...';
      case CallUiStatusState.poorConnection:
        return 'Poor Connection';
      case CallUiStatusState.cameraDisabled:
        return 'Camera Off';
      case CallUiStatusState.microphoneMuted:
        return 'Muted';
      case CallUiStatusState.callEnded:
        return 'Call Ended';
      case CallUiStatusState.userDeclined:
        return 'User Declined';
      case CallUiStatusState.userUnavailable:
        return 'User Unavailable';
    }
  }

  IconData? _getIconData() {
    switch (status) {
      case CallUiStatusState.calling:
      case CallUiStatusState.ringing:
      case CallUiStatusState.connecting:
      case CallUiStatusState.reconnecting:
        return null; // Uses spinner or custom dot
      case CallUiStatusState.connected:
        return LucideIcons.phone;
      case CallUiStatusState.poorConnection:
        return LucideIcons.wifiOff;
      case CallUiStatusState.cameraDisabled:
        return LucideIcons.videoOff;
      case CallUiStatusState.microphoneMuted:
        return LucideIcons.micOff;
      case CallUiStatusState.callEnded:
      case CallUiStatusState.userDeclined:
      case CallUiStatusState.userUnavailable:
        return LucideIcons.phoneOff;
    }
  }

  Color _getIconColor() {
    switch (status) {
      case CallUiStatusState.calling:
      case CallUiStatusState.ringing:
      case CallUiStatusState.connecting:
        return const Color(0xFF6366F1); // Indigo
      case CallUiStatusState.connected:
        return const Color(0xFF10B981); // Emerald green
      case CallUiStatusState.reconnecting:
      case CallUiStatusState.poorConnection:
        return const Color(0xFFF59E0B); // Amber warning
      case CallUiStatusState.cameraDisabled:
      case CallUiStatusState.microphoneMuted:
        return Colors.white70;
      case CallUiStatusState.callEnded:
      case CallUiStatusState.userDeclined:
      case CallUiStatusState.userUnavailable:
        return const Color(0xFFEF4444); // Red
    }
  }

  Color _getBackgroundColor(bool isDarkTheme) {
    if (isDarkTheme) {
      return Colors.black.withValues(alpha: 0.65);
    }
    return Colors.white.withValues(alpha: 0.9);
  }

  Color _getBorderColor(bool isDarkTheme) {
    if (isDarkTheme) {
      return Colors.white.withValues(alpha: 0.15);
    }
    return Colors.black.withValues(alpha: 0.08);
  }

  Color _getTextColor(bool isDarkTheme) {
    if (isDarkTheme) {
      return Colors.white;
    }
    return Colors.black87;
  }
}
