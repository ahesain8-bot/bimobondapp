import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';

class NotificationAdminHelper {
  NotificationAdminHelper._();

  static bool isAdminNotification(String type) {
    return switch (type) {
      'ADMIN_MESSAGE' || 'BROADCAST' || 'SYSTEM' => true,
      _ => false,
    };
  }

  static bool isAdminNotificationEntity(NotificationEntity notification) {
    return isAdminNotification(notification.type);
  }
}
