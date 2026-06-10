import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NotificationTypeStyle {
  NotificationTypeStyle._();

  static (IconData icon, Color color) forType(String type) {
    return switch (type) {
      'NEW_FOLLOWER' ||
      'FOLLOW_REQUEST' ||
      'FOLLOW_REQUEST_ACCEPTED' =>
        (LucideIcons.userPlus, MessagesLayoutConstants.activityFollowersColor),
      'POST_LIKE' || 'COMMENT_LIKE' =>
        (LucideIcons.heart, MessagesLayoutConstants.activityLikesColor),
      'POST_COMMENT' || 'COMMENT_REPLY' =>
        (LucideIcons.messageCircle, MessagesLayoutConstants.activityCommentsColor),
      'MENTION' => (
          LucideIcons.atSign,
          MessagesLayoutConstants.activityMentionsColor,
        ),
      'REPOST' => (LucideIcons.repeat2, const Color(0xFF5856D6)),
      'GIFT_RECEIVED' => (LucideIcons.gift, const Color(0xFFFF9500)),
      'AUCTION_UPDATE' || 'AUCTION_WON' =>
        (LucideIcons.gavel, const Color(0xFF34C759)),
      'ADMIN_MESSAGE' || 'BROADCAST' || 'SYSTEM' =>
        (LucideIcons.bell, MessagesLayoutConstants.activityNotificationsColor),
      _ => (LucideIcons.bell, MessagesLayoutConstants.activityNotificationsColor),
    };
  }
}
