import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_admin_helper.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> handleNotificationTap(
  BuildContext context,
  NotificationEntity notification, {
  PostEntity? post,
}) async {
  if (NotificationAdminHelper.isAdminNotificationEntity(notification)) {
    return;
  }
  await navigateFromNotification(context, notification, post: post);
}

Future<void> navigateFromNotification(
  BuildContext context,
  NotificationEntity notification, {
  PostEntity? post,
}) async {
  switch (notification.type) {
    case 'POST_LIKE':
    case 'POST_COMMENT':
    case 'REPOST':
    case 'MENTION':
      final postId = notification.postId ?? notification.post?.id;
      if (postId == null || postId.isEmpty) return;
      if (post != null) {
        openPost(context, post);
        return;
      }
      await openPostById(context, postId);
      return;
    case 'COMMENT_REPLY':
    case 'COMMENT_LIKE':
      final postId =
          notification.postId ?? notification.comment?.postId ?? notification.post?.id;
      if (postId == null || postId.isEmpty) return;
      final commentId = notification.commentId ?? notification.comment?.id;
      if (post != null) {
        openPost(
          context,
          post,
          openComments: true,
          highlightCommentId: commentId,
        );
        return;
      }
      await openPostById(
        context,
        postId,
        openComments: true,
        highlightCommentId: commentId,
      );
      return;
    case 'NEW_FOLLOWER':
    case 'FOLLOW_REQUEST':
    case 'FOLLOW_REQUEST_ACCEPTED':
      final actorId = notification.actorId ?? notification.actor?.id;
      if (actorId == null || actorId.isEmpty) return;
      await openUserStoryOrProfile(
        context,
        userId: actorId,
        username: notification.actor?.username,
      );
      return;
    case 'GIFT_RECEIVED':
      if (context.mounted) context.pushNamed('settings');
      return;
    case 'AUCTION_WON':
    case 'AUCTION_UPDATE':
      final auctionId = notification.data?['auctionId']?.toString();
      if (post != null && post.isAuctionable) {
        context.pushNamed('live_details', extra: {'post': post});
        return;
      }
      if (auctionId != null && auctionId.isNotEmpty) {
        context.pushNamed('live_details', extra: {'auctionId': auctionId});
      }
      return;
    case 'ADMIN_MESSAGE':
    case 'BROADCAST':
    case 'SYSTEM':
      return;
    default:
      return;
  }
}
