class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (statusCode: $statusCode)';
}

class BadRequestException extends ApiException {
  BadRequestException(super.message, {super.statusCode, super.details});
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message, {super.statusCode, super.details});
}

class NotFoundException extends ApiException {
  NotFoundException(super.message, {super.statusCode, super.details});
}

class ServiceUnavailableException extends ApiException {
  ServiceUnavailableException(super.message, {super.statusCode, super.details});
}
