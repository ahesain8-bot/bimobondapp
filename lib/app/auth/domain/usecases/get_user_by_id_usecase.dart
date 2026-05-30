import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetUserByIdUseCase implements UseCase<UserEntity, GetUserByIdParams> {
  GetUserByIdUseCase(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, UserEntity>> call(GetUserByIdParams params) {
    return repository.getUserById(params.userId);
  }
}

class GetUserByIdParams extends Equatable {
  const GetUserByIdParams(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}
