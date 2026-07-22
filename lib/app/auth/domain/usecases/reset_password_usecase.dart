import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';

class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  ResetPasswordUseCase(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) {
    return repository.resetPassword(
      type: params.type,
      code: params.code,
      newPassword: params.newPassword,
      email: params.email,
      phoneNumber: params.phoneNumber,
    );
  }
}

class ResetPasswordParams extends Equatable {
  const ResetPasswordParams({
    required this.type,
    required this.code,
    required this.newPassword,
    this.email,
    this.phoneNumber,
  });

  final String type;
  final String code;
  final String newPassword;
  final String? email;
  final String? phoneNumber;

  @override
  List<Object?> get props => [type, code, newPassword, email, phoneNumber];
}
