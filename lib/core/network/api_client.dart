import 'package:dio/dio.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late final Dio _dio;
  final SharedPreferences sharedPreferences;

  ApiClient({required this.sharedPreferences}) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiConstants.apiKey,
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));

    // Custom interceptor for Auth Tokens or extra headers
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final authToken = sharedPreferences.getString('AUTH_TOKEN');
        final deviceToken = sharedPreferences.getString('DEVICE_TOKEN');
        
        if (authToken != null && authToken.isNotEmpty) {
          // Only add the token if it's not already provided in the request options
          if (!options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer $authToken';
          }
        }
        if (deviceToken != null && deviceToken.isNotEmpty) {
          options.headers['device-token'] = deviceToken;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        throw DioHandler.handle(e);
      },
    ));
  }

  Dio get dio => _dio;
}
