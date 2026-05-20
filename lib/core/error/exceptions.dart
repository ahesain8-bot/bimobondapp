abstract class AppException implements Exception {
  final String? message;

  AppException({this.message});
}

class ServerException extends AppException {
  ServerException({super.message});
}

class CacheException extends AppException {
  CacheException({super.message});
}

class NetworkException extends AppException {
  NetworkException({super.message});
}

class RequestTimeoutException extends AppException {
  RequestTimeoutException({super.message});
}

class UnauthorizedException extends AppException {
  UnauthorizedException({super.message});
}

class ForbiddenException extends AppException {
  ForbiddenException({super.message});
}

class NotFoundException extends AppException {
  NotFoundException({super.message});
}
