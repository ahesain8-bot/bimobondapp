import 'package:bimobondapp/app/notifications/data/models/notification_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class NotificationsRemoteDataSource {
  Future<NotificationsPageModel> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
  });

  Future<int> getUnreadCount();

  Future<NotificationModel> markAsRead(String id);

  Future<int> markAllAsRead();

  Future<void> deleteNotification(String id);

  Future<int> clearReadNotifications();
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  NotificationsRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw UnauthorizedException(message: 'User not authenticated');
    }
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<T> _execute<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<NotificationsPageModel> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
  }) {
    return _execute(() async {
      final response = await apiClient.dio.get(
        ApiConstants.notifications,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (type != null && type.isNotEmpty) 'type': type,
          if (isRead != null) 'isRead': isRead ? 'true' : 'false',
        },
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        return NotificationsPageModel.fromResponse(
          response.data,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(message: 'Failed to load notifications');
    });
  }

  @override
  Future<int> getUnreadCount() {
    return _execute(() async {
      final response = await apiClient.dio.get(
        ApiConstants.notificationsUnreadCount,
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return _parseCount(data['unreadCount']);
        }
      }

      throw ServerException(message: 'Failed to load unread count');
    });
  }

  @override
  Future<NotificationModel> markAsRead(String id) {
    return _execute(() async {
      final response = await apiClient.dio.patch(
        ApiConstants.notificationRead(id),
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return NotificationModel.fromJson(Map<String, dynamic>.from(data));
        }
      }

      throw ServerException(message: 'Failed to mark notification as read');
    });
  }

  @override
  Future<int> markAllAsRead() {
    return _execute(() async {
      final response = await apiClient.dio.patch(
        ApiConstants.notificationsReadAll,
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return _parseCount(data['unreadCount']);
        }
        return 0;
      }

      throw ServerException(message: 'Failed to mark all as read');
    });
  }

  @override
  Future<void> deleteNotification(String id) {
    return _execute(() async {
      final response = await apiClient.dio.delete(
        ApiConstants.notificationById(id),
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode != 200) {
        throw ServerException(message: 'Failed to delete notification');
      }
    });
  }

  @override
  Future<int> clearReadNotifications() {
    return _execute(() async {
      final response = await apiClient.dio.delete(
        ApiConstants.notificationsClearRead,
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return _parseCount(data['deletedCount']);
        }
        return 0;
      }

      throw ServerException(message: 'Failed to clear read notifications');
    });
  }

  int _parseCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
