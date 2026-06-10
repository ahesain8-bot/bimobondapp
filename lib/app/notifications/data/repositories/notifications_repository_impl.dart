import 'package:bimobondapp/app/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/domain/repositories/notifications_repository.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({required this.remoteDataSource});

  final NotificationsRemoteDataSource remoteDataSource;

  Failure _mapException(Object e) {
    if (e is ServerException) {
      return ServerFailure(e.message ?? 'Something went wrong');
    }
    if (e is UnauthorizedException) {
      return UnauthorizedFailure(e.message ?? 'Unauthorized');
    }
    return ServerFailure(e.toString());
  }

  @override
  Future<Either<Failure, NotificationsPageEntity>> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
  }) async {
    try {
      final pageModel = await remoteDataSource.getNotifications(
        page: page,
        limit: limit,
        type: type,
        isRead: isRead,
      );
      return Right(pageModel);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final count = await remoteDataSource.getUnreadCount();
      return Right(count);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, NotificationEntity>> markAsRead(String id) async {
    try {
      final notification = await remoteDataSource.markAsRead(id);
      return Right(notification);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, int>> markAllAsRead() async {
    try {
      final count = await remoteDataSource.markAllAsRead();
      return Right(count);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteNotification(String id) async {
    try {
      await remoteDataSource.deleteNotification(id);
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, int>> clearReadNotifications() async {
    try {
      final count = await remoteDataSource.clearReadNotifications();
      return Right(count);
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
