import 'package:bimobondapp/app/social/domain/entities/user_likes_page_entity.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetMyLikesUseCase
    implements UseCase<UserLikesPageEntity, GetMyLikesParams> {
  GetMyLikesUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, UserLikesPageEntity>> call(
    GetMyLikesParams params,
  ) async {
    return repository.getMyLikes(
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetMyLikesParams extends Equatable {
  const GetMyLikesParams({
    this.page = 1,
    this.limit = 10,
  });

  final int page;
  final int limit;

  @override
  List<Object?> get props => [page, limit];
}
