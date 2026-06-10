import 'package:bimobondapp/app/posts/domain/entities/toggle_repost_params.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class ToggleRepostPostUsecase
    implements UseCase<bool, ToggleRepostParams> {
  ToggleRepostPostUsecase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, bool>> call(ToggleRepostParams params) {
    return repository.toggleRepost(
      params.postId,
      quote: params.quote,
    );
  }
}
