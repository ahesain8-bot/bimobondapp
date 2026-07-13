import 'package:bimobondapp/app/interests/data/datasources/interests_remote_data_source.dart';
import 'package:bimobondapp/app/interests/domain/entities/user_interest_entity.dart';
import 'package:bimobondapp/app/interests/domain/repositories/interests_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class InterestsRepositoryImpl implements InterestsRepository {
  InterestsRepositoryImpl({required this.remoteDataSource});

  final InterestsRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, UserInterestsResult>> getMyInterests() async {
    try {
      final result = await remoteDataSource.getMyInterests();
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, UserInterestsResult>> setMyInterests({
    required List<String> categoryIds,
    List<String>? notInterestedCategoryIds,
  }) async {
    try {
      final result = await remoteDataSource.setMyInterests(
        categoryIds: categoryIds,
        notInterestedCategoryIds: notInterestedCategoryIds,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
