import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dio/dio.dart';

class FailureMapper {
  FailureMapper._();

  static Failure from(Object error) {
    if (error is Failure) return error;

    final resolved = _resolveSource(error);
    final message = ErrorMessageResolver.resolve(resolved);

    if (resolved is UnauthorizedException) {
      return UnauthorizedFailure(message);
    }
    if (resolved is NetworkException) {
      return NetworkFailure(message);
    }
    if (resolved is RequestTimeoutException) {
      return TimeoutFailure(message);
    }
    if (resolved is CacheException) {
      return CacheFailure(message);
    }
    if (resolved is AppException) {
      return ServerFailure(message);
    }
    return UnknownFailure(message);
  }

  static Object _resolveSource(Object error) {
    if (error is AppException) return error;
    if (error is DioException) {
      if (error.error is AppException) {
        return error.error as AppException;
      }
      final handled = DioHandler.handle(error);
      if (handled is AppException) return handled;
    }
    return error;
  }
}
