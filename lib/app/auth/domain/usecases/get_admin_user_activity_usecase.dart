import 'package:bimobondapp/app/auth/domain/entities/user_activity_page_entity.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/core/error/failures.dart';

class GetAdminUserActivityUseCase
    implements UseCase<UserActivityPageEntity, GetAdminUserActivityParams> {
  GetAdminUserActivityUseCase(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, UserActivityPageEntity>> call(
    GetAdminUserActivityParams params,
  ) {
    return repository.getAdminUserActivity(
      params.userId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetAdminUserActivityParams extends Equatable {
  const GetAdminUserActivityParams({
    required this.userId,
    this.page = 1,
    this.limit = 10,
  });

  final String userId;
  final int page;
  final int limit;

  @override
  List<Object?> get props => [userId, page, limit];
}
