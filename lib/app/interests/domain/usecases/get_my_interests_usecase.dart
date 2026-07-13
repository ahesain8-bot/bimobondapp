import 'package:bimobondapp/app/interests/domain/entities/user_interest_entity.dart';
import 'package:bimobondapp/app/interests/domain/repositories/interests_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetMyInterestsUseCase
    implements UseCase<UserInterestsResult, NoParams> {
  GetMyInterestsUseCase(this.repository);

  final InterestsRepository repository;

  @override
  Future<Either<Failure, UserInterestsResult>> call(NoParams params) {
    return repository.getMyInterests();
  }
}
