import 'package:dio/dio.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network_console.dart';

class ApiClient {
  late final Dio _dio;
  final SharedPreferences sharedPreferences;

  static const _authTokenKey = 'AUTH_TOKEN';
  static const _deviceTokenKey = 'DEVICE_TOKEN';
  static const _retriedExtraKey = 'firebase_auth_retried';

  ApiClient({required this.sharedPreferences}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiConstants.apiKey,
        },
      ),
    );

    // Queued so concurrent requests wait for a single token refresh.
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _resolveFirebaseIdToken(forceRefresh: false);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              final cached = sharedPreferences.getString(_authTokenKey);
              if (cached != null &&
                  cached.isNotEmpty &&
                  !options.headers.containsKey('Authorization')) {
                options.headers['Authorization'] = 'Bearer $cached';
              }
            }
          } catch (e, st) {
            debugPrint('ApiClient auth header: $e\n$st');
            final cached = sharedPreferences.getString(_authTokenKey);
            if (cached != null &&
                cached.isNotEmpty &&
                !options.headers.containsKey('Authorization')) {
              options.headers['Authorization'] = 'Bearer $cached';
            }
          }

          final deviceToken = sharedPreferences.getString(_deviceTokenKey);
          if (deviceToken != null && deviceToken.isNotEmpty) {
            options.headers['device-token'] = deviceToken;
          }
          return handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) async {
          if (_shouldRefreshAndRetry(error)) {
            try {
              final token = await _resolveFirebaseIdToken(forceRefresh: true);
              if (token != null && token.isNotEmpty) {
                final req = error.requestOptions;
                req.headers['Authorization'] = 'Bearer $token';
                req.extra[_retriedExtraKey] = true;
                final response = await _dio.fetch(req);
                return handler.resolve(response);
              }
            } catch (e, st) {
              debugPrint('ApiClient 401 retry failed: $e\n$st');
            }
          }

          final exception = DioHandler.handle(error);
          if (exception is AppException) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: error.type,
                error: exception,
                message: exception.message,
              ),
            );
          }
          return handler.next(error);
        },
      ),
    );

    // Postman-style debug traces with bounded payload previews. It is placed
    // after auth so the report reflects the outgoing request, while secrets
    // remain redacted by [NetworkConsoleInterceptor].
    if (kDebugMode) {
      _dio.interceptors.add(NetworkConsoleInterceptor());
    }
  }

  bool _shouldRefreshAndRetry(DioException error) {
    if (error.response?.statusCode != 401) return false;
    if (error.requestOptions.extra[_retriedExtraKey] == true) return false;
    final message = '${error.response?.data ?? error.message}'.toLowerCase();
    return message.contains('expired') ||
        message.contains('unauthorized') ||
        message.contains('id token') ||
        message.contains('firebase');
  }

  /// Fresh Firebase ID token. [getIdToken] refreshes when expired;
  /// [forceRefresh] forces a new token after a 401.
  Future<String?> _resolveFirebaseIdToken({required bool forceRefresh}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken(forceRefresh);
    if (token != null && token.isNotEmpty) {
      await sharedPreferences.setString(_authTokenKey, token);
    }
    return token;
  }

  Dio get dio => _dio;
}
