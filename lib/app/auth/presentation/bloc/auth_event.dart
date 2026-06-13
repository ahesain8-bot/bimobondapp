import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {}

class LoginSubmittedEvent extends AuthEvent {
  final String name;
  final String password;

  const LoginSubmittedEvent({required this.name, required this.password});

  @override
  List<Object> get props => [name, password];
}

class VerifyPhoneEvent extends AuthEvent {
  final String phoneNumber;

  const VerifyPhoneEvent({required this.phoneNumber});

  @override
  List<Object> get props => [phoneNumber];
}

class PhoneCodeSentEvent extends AuthEvent {
  final String verificationId;
  final int? resendToken;

  const PhoneCodeSentEvent({required this.verificationId, this.resendToken});

  @override
  List<Object> get props => [verificationId, resendToken ?? 0];
}

class PhoneAuthFailedEvent extends AuthEvent {
  final String message;
  final String? messageKey;

  const PhoneAuthFailedEvent({required this.message, this.messageKey});

  @override
  List<Object> get props => [message];
}

class SubmitOtpEvent extends AuthEvent {
  final String verificationId;
  final String smsCode;

  const SubmitOtpEvent({required this.verificationId, required this.smsCode});

  @override
  List<Object> get props => [verificationId, smsCode];
}

class FacebookLoginRequestedEvent extends AuthEvent {
  const FacebookLoginRequestedEvent();

  @override
  List<Object> get props => [];
}

class GoogleLoginRequestedEvent extends AuthEvent {
  const GoogleLoginRequestedEvent();

  @override
  List<Object> get props => [];
}

class UpdateProfileRequestedEvent extends AuthEvent {
  final Map<String, dynamic> data;

  const UpdateProfileRequestedEvent(this.data);

  @override
  List<Object> get props => [data];
}

class SendEmailOtpEvent extends AuthEvent {
  final String email;

  const SendEmailOtpEvent({required this.email});

  @override
  List<Object> get props => [email];
}

class VerifyEmailOtpEvent extends AuthEvent {
  final String email;
  final String otpCode;

  const VerifyEmailOtpEvent({required this.email, required this.otpCode});

  @override
  List<Object> get props => [email, otpCode];
}

class FetchProfileEvent extends AuthEvent {
  const FetchProfileEvent();

  @override
  List<Object> get props => [];
}

class LogoutRequestedEvent extends AuthEvent {
  const LogoutRequestedEvent();

  @override
  List<Object> get props => [];
}

class SignUpWithEmailEvent extends AuthEvent {
  final String fullName;
  final String email;
  final String password;

  const SignUpWithEmailEvent({
    required this.fullName,
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [fullName, email, password];
}
