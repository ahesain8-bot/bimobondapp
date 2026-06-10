import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/domain/repositories/notifications_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class GetNotificationsUseCase {
  GetNotificationsUseCase(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, NotificationsPageEntity>> call(
    GetNotificationsParams params,
  ) {
    return repository.getNotifications(
      page: params.page,
      limit: params.limit,
      type: params.type,
      isRead: params.isRead,
    );
  }
}

class GetNotificationsParams {
  const GetNotificationsParams({
    this.page = 1,
    this.limit = 20,
    this.type,
    this.isRead,
  });

  final int page;
  final int limit;
  final String? type;
  final bool? isRead;
}

class GetUnreadNotificationsCountUseCase {
  GetUnreadNotificationsCountUseCase(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, int>> call() => repository.getUnreadCount();
}

class MarkNotificationReadUseCase {
  MarkNotificationReadUseCase(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, NotificationEntity>> call(String id) {
    return repository.markAsRead(id);
  }
}

class MarkAllNotificationsReadUseCase {
  MarkAllNotificationsReadUseCase(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, int>> call() => repository.markAllAsRead();
}

class DeleteNotificationUseCase {
  DeleteNotificationUseCase(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteNotification(id);
  }
}

class ClearReadNotificationsUseCase {
  ClearReadNotificationsUseCase(this.repository);

  final NotificationsRepository repository;

  Future<Either<Failure, int>> call() => repository.clearReadNotifications();
}
