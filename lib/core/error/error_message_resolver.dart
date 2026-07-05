import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dio/dio.dart';

/// Resolves user-facing text from any error thrown in the app.
class ErrorMessageResolver {
  ErrorMessageResolver._();

  static const fallbackMessage = 'Something went wrong';

  static String resolve(Object? error) {
    if (error == null) return fallbackMessage;

    if (error is Failure) {
      return _nonEmpty(error.message) ?? fallbackMessage;
    }

    if (error is AppException) {
      return _nonEmpty(error.message) ?? fallbackMessage;
    }

    if (error is DioException) {
      if (error.error is AppException) {
        return resolve(error.error);
      }
      final handled = DioHandler.handle(error);
      if (handled is AppException) {
        return _nonEmpty(handled.message) ?? fallbackMessage;
      }
    }

    final text = error.toString().trim();
    if (text.isEmpty || text.startsWith('Instance of ')) {
      return fallbackMessage;
    }
    return text;
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
