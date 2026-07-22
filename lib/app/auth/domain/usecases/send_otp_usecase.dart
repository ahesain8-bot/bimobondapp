import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';

class SendOtpUseCase implements UseCase<void, SendOtpParams> {
  SendOtpUseCase(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(SendOtpParams params) {
    return repository.sendOtp(
      type: params.type,
      email: params.email,
      phoneNumber: params.phoneNumber,
    );
  }
}

class SendOtpParams extends Equatable {
  const SendOtpParams({
    required this.type,
    this.email,
    this.phoneNumber,
  });

  final String type;
  final String? email;
  final String? phoneNumber;

  @override
  List<Object?> get props => [type, email, phoneNumber];
}
