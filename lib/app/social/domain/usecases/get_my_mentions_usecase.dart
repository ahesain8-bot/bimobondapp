import 'package:bimobondapp/app/social/domain/entities/user_mentions_page_entity.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetMyMentionsUseCase
    implements UseCase<UserMentionsPageEntity, GetMyMentionsParams> {
  GetMyMentionsUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, UserMentionsPageEntity>> call(
    GetMyMentionsParams params,
  ) async {
    return repository.getMyMentions(
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetMyMentionsParams extends Equatable {
  const GetMyMentionsParams({
    this.page = 1,
    this.limit = 10,
  });

  final int page;
  final int limit;

  @override
  List<Object?> get props => [page, limit];
}
