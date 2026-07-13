import 'package:bimobondapp/app/interests/domain/entities/user_interest_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class InterestsRepository {
  Future<Either<Failure, UserInterestsResult>> getMyInterests();

  Future<Either<Failure, UserInterestsResult>> setMyInterests({
    required List<String> categoryIds,
    List<String>? notInterestedCategoryIds,
  });
}
