import 'package:bimobondapp/app/interests/domain/entities/user_interest_entity.dart';
import 'package:bimobondapp/app/interests/domain/repositories/interests_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class SetMyInterestsUseCase
    implements UseCase<UserInterestsResult, SetMyInterestsParams> {
  SetMyInterestsUseCase(this.repository);

  final InterestsRepository repository;

  @override
  Future<Either<Failure, UserInterestsResult>> call(
    SetMyInterestsParams params,
  ) {
    return repository.setMyInterests(
      categoryIds: params.categoryIds,
      notInterestedCategoryIds: params.notInterestedCategoryIds,
    );
  }
}

class SetMyInterestsParams extends Equatable {
  const SetMyInterestsParams({
    required this.categoryIds,
    this.notInterestedCategoryIds,
  });

  final List<String> categoryIds;
  final List<String>? notInterestedCategoryIds;

  @override
  List<Object?> get props => [categoryIds, notInterestedCategoryIds];
}
