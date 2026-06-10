import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class NotificationDisplayText {
  NotificationDisplayText._();

  static String title(AppLocalizations l10n, NotificationEntity notification) {
    if (notification.title?.trim().isNotEmpty == true) {
      return notification.title!.trim();
    }
    return _defaultTitle(l10n, notification.type);
  }

  static String body(AppLocalizations l10n, NotificationEntity notification) {
    if (notification.body?.trim().isNotEmpty == true) {
      return notification.body!.trim();
    }
    final name = notification.actor?.displayName ?? l10n.notificationSomeone;
    return _defaultBody(l10n, notification.type, name);
  }

  static String _defaultTitle(AppLocalizations l10n, String type) {
    return switch (type) {
      'NEW_FOLLOWER' => l10n.notificationTitleNewFollower,
      'FOLLOW_REQUEST' => l10n.notificationTitleFollowRequest,
      'FOLLOW_REQUEST_ACCEPTED' => l10n.notificationTitleFollowAccepted,
      'POST_LIKE' => l10n.notificationTitlePostLike,
      'POST_COMMENT' => l10n.notificationTitlePostComment,
      'COMMENT_REPLY' => l10n.notificationTitleCommentReply,
      'COMMENT_LIKE' => l10n.notificationTitleCommentLike,
      'MENTION' => l10n.notificationTitleMention,
      'REPOST' => l10n.notificationTitleRepost,
      'GIFT_RECEIVED' => l10n.notificationTitleGift,
      'AUCTION_UPDATE' => l10n.notificationTitleAuctionUpdate,
      'AUCTION_WON' => l10n.notificationTitleAuctionWon,
      _ => l10n.notificationTitleDefault,
    };
  }

  static String _defaultBody(
    AppLocalizations l10n,
    String type,
    String name,
  ) {
    return switch (type) {
      'NEW_FOLLOWER' => l10n.notificationBodyNewFollower(name),
      'FOLLOW_REQUEST' => l10n.notificationBodyFollowRequest(name),
      'FOLLOW_REQUEST_ACCEPTED' => l10n.notificationBodyFollowAccepted(name),
      'POST_LIKE' => l10n.notificationBodyPostLike(name),
      'POST_COMMENT' => l10n.notificationBodyPostComment(name),
      'COMMENT_REPLY' => l10n.notificationBodyCommentReply(name),
      'COMMENT_LIKE' => l10n.notificationBodyCommentLike(name),
      'MENTION' => l10n.notificationBodyMention(name),
      'REPOST' => l10n.notificationBodyRepost(name),
      'GIFT_RECEIVED' => l10n.notificationBodyGift(name),
      'AUCTION_UPDATE' => l10n.notificationBodyAuctionUpdate,
      'AUCTION_WON' => l10n.notificationBodyAuctionWon,
      _ => l10n.notificationBodyDefault,
    };
  }
}
