import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class NotificationsRepository {
  Future<Either<Failure, NotificationsPageEntity>> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
  });

  Future<Either<Failure, int>> getUnreadCount();

  Future<Either<Failure, NotificationEntity>> markAsRead(String id);

  Future<Either<Failure, int>> markAllAsRead();

  Future<Either<Failure, void>> deleteNotification(String id);

  Future<Either<Failure, int>> clearReadNotifications();
}
