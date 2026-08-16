import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_admin_helper.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/app/calls/domain/usecases/get_call_by_id_usecase.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/di/calls_injector.dart' as calls_di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        openPost(
          context,
          post,
          trafficSource: TrafficSource.notification,
        );
        return;
      }
      await openPostById(
        context,
        postId,
        trafficSource: TrafficSource.notification,
      );
      return;
    case 'COMMENT_REPLY':
    case 'COMMENT_LIKE':
      final postId =
          notification.postId ??
          notification.comment?.postId ??
          notification.post?.id;
      if (postId == null || postId.isEmpty) return;
      final commentId = notification.commentId ?? notification.comment?.id;
      if (post != null) {
        openPost(
          context,
          post,
          openComments: true,
          highlightCommentId: commentId,
          trafficSource: TrafficSource.notification,
        );
        return;
      }
      await openPostById(
        context,
        postId,
        openComments: true,
        highlightCommentId: commentId,
        trafficSource: TrafficSource.notification,
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
        context.pushNamed(
          'live_details',
          extra: {
            'post': post,
            'trafficSource': TrafficSource.notification,
          },
        );
        return;
      }
      if (auctionId != null && auctionId.isNotEmpty) {
        context.pushNamed(
          'live_details',
          extra: {
            'auctionId': auctionId,
            'trafficSource': TrafficSource.notification,
          },
        );
      }
      return;
    case 'CALL_INCOMING':
      final callId = notification.data?['callId']?.toString();
      final chatId = notification.data?['chatId']?.toString();
      if (callId != null && callId.isNotEmpty && context.mounted) {
        try {
          final getCallById = calls_di.sl<GetCallByIdUseCase>();
          final result = await getCallById(callId: callId);
          result.fold(
            (_) {
              if (chatId != null && chatId.isNotEmpty && context.mounted) {
                context.pushNamed('chat', extra: {'chatId': chatId});
              }
            },
            (call) {
              if (context.mounted) {
                context.read<CallBloc>().add(IncomingCallReceivedEvent(call: call));
              }
            },
          );
        } catch (_) {
          if (chatId != null && chatId.isNotEmpty && context.mounted) {
            context.pushNamed('chat', extra: {'chatId': chatId});
          }
        }
      } else if (chatId != null && chatId.isNotEmpty && context.mounted) {
        context.pushNamed('chat', extra: {'chatId': chatId});
      }
      return;
    case 'CALL_MISSED':
      final chatId = notification.data?['chatId']?.toString();
      if (chatId != null && chatId.isNotEmpty && context.mounted) {
        context.pushNamed('chat', extra: {'chatId': chatId});
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
