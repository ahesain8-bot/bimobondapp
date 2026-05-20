import 'package:dartz/dartz.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';

class SignInWithPhoneUseCase {
  final AuthRepository repository;

  SignInWithPhoneUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String verificationId,
    required String smsCode,
  }) async {
    return await repository.signInWithPhoneNumber(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
}
