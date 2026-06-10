import 'package:bimobondapp/app/notifications/data/datasources/notification_socket_service.dart';
import 'package:bimobondapp/app/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:bimobondapp/app/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:bimobondapp/app/notifications/domain/repositories/notifications_repository.dart';
import 'package:bimobondapp/app/notifications/domain/usecases/notifications_usecases.dart';
import 'package:bimobondapp/app/notifications/presentation/services/notification_coordinator.dart';
import 'package:bimobondapp/app/notifications/presentation/services/notification_unread_badge.dart';
import 'package:bimobondapp/app/notifications/presentation/services/push_notification_service.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initNotifications() async {
  sl.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<NotificationSocketService>(
    () => NotificationSocketService(),
  );
  sl.registerLazySingleton(() => GetNotificationsUseCase(sl()));
  sl.registerLazySingleton(() => GetUnreadNotificationsCountUseCase(sl()));
  sl.registerLazySingleton(() => MarkNotificationReadUseCase(sl()));
  sl.registerLazySingleton(() => MarkAllNotificationsReadUseCase(sl()));
  sl.registerLazySingleton(() => DeleteNotificationUseCase(sl()));
  sl.registerLazySingleton(() => ClearReadNotificationsUseCase(sl()));
  sl.registerLazySingleton(
    () => NotificationUnreadBadge(
      getUnreadCountUseCase: sl(),
      socketService: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => NotificationCoordinator(
      socketService: sl(),
      pushService: PushNotificationService.instance,
      authRemoteDataSource: sl(),
      unreadBadge: sl(),
    ),
  );
}
