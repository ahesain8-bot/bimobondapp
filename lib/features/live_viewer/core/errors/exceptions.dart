abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class ServerException extends AppException {
  const ServerException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class NetworkException extends AppException {
  const NetworkException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class CacheException extends AppException {
  const CacheException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException(
    String message, {
    this.fieldErrors,
    String? code,
    dynamic details,
  }) : super(message, code: code, details: details);
}

class AuthenticationException extends AppException {
  const AuthenticationException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class AuthorizationException extends AppException {
  const AuthorizationException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class NotFoundException extends AppException {
  const NotFoundException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class TimeoutException extends AppException {
  const TimeoutException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class UnknownException extends AppException {
  const UnknownException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class WebsocketException extends AppException {
  const WebsocketException(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}
