import 'package:bimobondapp/app/social/domain/entities/user_comments_page_entity.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetUserCommentsUseCase
    implements UseCase<UserCommentsPageEntity, GetUserCommentsParams> {
  GetUserCommentsUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, UserCommentsPageEntity>> call(
    GetUserCommentsParams params,
  ) {
    return repository.getUserComments(
      userId: params.userId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetUserCommentsParams extends Equatable {
  const GetUserCommentsParams({
    this.userId,
    this.page = 1,
    this.limit = 10,
  });

  final String? userId;
  final int page;
  final int limit;

  @override
  List<Object?> get props => [userId, page, limit];
}
