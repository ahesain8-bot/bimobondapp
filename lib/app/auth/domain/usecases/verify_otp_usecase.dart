import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';

class VerifyOtpUseCase implements UseCase<void, VerifyOtpParams> {
  VerifyOtpUseCase(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(VerifyOtpParams params) {
    return repository.verifyOtp(
      type: params.type,
      code: params.code,
      email: params.email,
      phoneNumber: params.phoneNumber,
    );
  }
}

class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({
    required this.type,
    required this.code,
    this.email,
    this.phoneNumber,
  });

  final String type;
  final String code;
  final String? email;
  final String? phoneNumber;

  @override
  List<Object?> get props => [type, code, email, phoneNumber];
}
