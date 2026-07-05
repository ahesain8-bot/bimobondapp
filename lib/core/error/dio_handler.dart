import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'exceptions.dart';

class DioHandler {
  static String? extractErrorMessage(dynamic data) {
    if (data is! Map) return null;

    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    if (message is List) {
      return message.map((e) => e.toString()).join('\n');
    }

    final error = data['error'];
    if (error is String && error.isNotEmpty) return error;

    return null;
  }

  static Exception handle(dynamic e) {
    if (e is DioException) {
      if (e.error is AppException) {
        return e.error as AppException;
      }

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return RequestTimeoutException(message: 'Request timeout');

        case DioExceptionType.badResponse:
          final apiMessage = extractErrorMessage(e.response?.data);
          final statusCode = e.response?.statusCode;

          switch (statusCode) {
            case 401:
              return UnauthorizedException(
                message: apiMessage ?? 'Unauthorized',
              );

            case 403:
              return ForbiddenException(message: apiMessage ?? 'Forbidden');

            case 404:
              return NotFoundException(message: apiMessage ?? 'Not Found');

            case 500:
              return ServerException(message: apiMessage ?? 'Server Error');

            default:
              return ServerException(
                message: apiMessage ?? 'Something went wrong',
              );
          }

        case DioExceptionType.connectionError:
          return NetworkException(message: 'No internet connection');

        default:
          return ServerException(message: 'Unexpected network error');
      }
    } else if (e is FirebaseAuthException) {
      return ServerException(message: e.message ?? 'Authentication error');
    } else if (e is PlatformException) {
      return ServerException(message: e.message ?? 'Platform error');
    } else if (e is AppException) {
      return e;
    } else {
      return ServerException(message: e.toString());
    }
  }
}
