import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

NotificationEntity notificationFromRemoteMessage(RemoteMessage message) {
  final data = Map<String, dynamic>.from(message.data);
  final auctionId = data['auctionId']?.toString();

  return NotificationEntity(
    id: data['notificationId']?.toString() ?? '',
    userId: data['userId']?.toString() ?? '',
    type: data['type']?.toString() ?? 'SYSTEM',
    isRead: false,
    createdAt: DateTime.now(),
    actorId: data['actorId']?.toString(),
    title: message.notification?.title ?? data['title']?.toString(),
    body: message.notification?.body ?? data['body']?.toString(),
    postId: data['postId']?.toString(),
    commentId: data['commentId']?.toString(),
    data: auctionId != null ? {'auctionId': auctionId} : null,
  );
}

String pushTitle(RemoteMessage message) {
  final fromNotification = message.notification?.title?.trim();
  if (fromNotification != null && fromNotification.isNotEmpty) {
    return fromNotification;
  }
  final fromData = message.data['title']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) return fromData;
  return 'Bimo Bond';
}

String pushBody(RemoteMessage message) {
  final fromNotification = message.notification?.body?.trim();
  if (fromNotification != null && fromNotification.isNotEmpty) {
    return fromNotification;
  }
  final fromData = message.data['body']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) return fromData;
  return 'You have a new notification';
}
