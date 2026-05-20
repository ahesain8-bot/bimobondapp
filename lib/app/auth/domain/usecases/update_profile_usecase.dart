import 'package:dartz/dartz.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';

class UpdateProfileUseCase implements UseCase<UserEntity, Map<String, dynamic>> {
  final AuthRepository repository;

  UpdateProfileUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(Map<String, dynamic> params) async {
    return await repository.updateProfile(params);
  }
}
