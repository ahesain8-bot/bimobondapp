import 'package:flutter/material.dart';

/// TikTok-style Gifter Level badge widget (`[Lv. X]`).
/// Displays level indicator next to user name in profiles, feeds, and live chat.
class GifterLevelBadge extends StatelessWidget {
  final int level;
  final bool compact;
  final TextStyle? textStyle;

  const GifterLevelBadge({
    super.key,
    required this.level,
    this.compact = false,
    this.textStyle,
  });

  LinearGradient _getBadgeGradient(int level) {
    if (level >= 50) {
      return const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFF4500), Color(0xFFFF007F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (level >= 30) {
      return const LinearGradient(
        colors: [Color(0xFF9D50BB), Color(0xFF6E48AA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (level >= 20) {
      return const LinearGradient(
        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (level >= 10) {
      return const LinearGradient(
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (level >= 5) {
      return const LinearGradient(
        colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return const SizedBox.shrink();

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 2);

    final fontSize = compact ? 10.0 : 11.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: _getBadgeGradient(level),
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.military_tech_rounded,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            'Lv. $level',
            style: textStyle ??
                TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
