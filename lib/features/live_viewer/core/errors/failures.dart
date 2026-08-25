import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic details;

  const Failure(this.message, {this.code, this.details});

  @override
  List<Object?> get props => [message, code, details];

  @override
  String toString() => 'Failure: $message (code: $code)';
}

class ServerFailure extends Failure {
  const ServerFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class CacheFailure extends Failure {
  const CacheFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;

  const ValidationFailure(
    String message, {
    this.fieldErrors,
    String? code,
    dynamic details,
  }) : super(message, code: code, details: details);

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class AuthorizationFailure extends Failure {
  const AuthorizationFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class UnknownFailure extends Failure {
  const UnknownFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}

class WebsocketFailure extends Failure {
  const WebsocketFailure(String message, {String? code, dynamic details})
    : super(message, code: code, details: details);
}
