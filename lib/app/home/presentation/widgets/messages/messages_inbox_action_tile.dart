import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:flutter/material.dart';

/// TikTok-style system / activity row used above the conversation list.
class MessagesInboxActionTile extends StatelessWidget {
  const MessagesInboxActionTile({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showChevron = true,
    this.badgeCount,
    super.key,
  });

  final IconData icon;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showChevron;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final hasBadge = badgeCount != null && badgeCount! > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MessagesLayoutConstants.horizontalPadding,
          vertical: 10,
        ),
        child: Row(
          children: [
            Container(
              width: MessagesLayoutConstants.conversationAvatarRadius * 2,
              height: MessagesLayoutConstants.conversationAvatarRadius * 2,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: MessagesLayoutConstants.conversationAvatarRadius,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: chatTheme.inboxSecondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (hasBadge)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: MessagesLayoutConstants.activityBadgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 20),
                child: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: chatTheme.inboxChevron,
                size: 26,
              ),
          ],
        ),
      ),
    );
  }
}
