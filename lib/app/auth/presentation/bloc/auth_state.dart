import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final UserEntity user;

  const AuthSuccess({required this.user});

  @override
  List<Object> get props => [user];
}

class AuthFailure extends AuthState {
  final String message;
  final String? messageKey;

  const AuthFailure({required this.message, this.messageKey});

  @override
  List<Object> get props => [message];
}

class PhoneCodeSentState extends AuthState {
  final String verificationId;
  final int? resendToken;

  const PhoneCodeSentState({required this.verificationId, this.resendToken});

  @override
  List<Object> get props => [verificationId, resendToken ?? 0];
}

class EmailOtpSentState extends AuthState {
  final String email;

  const EmailOtpSentState({required this.email});

  @override
  List<Object> get props => [email];
}

class EmailVerificationSentState extends AuthState {
  final String email;

  const EmailVerificationSentState({required this.email});

  @override
  List<Object> get props => [email];
}

class EmailOtpVerifiedState extends AuthState {
  final String email;

  const EmailOtpVerifiedState({required this.email});

  @override
  List<Object> get props => [email];
}
