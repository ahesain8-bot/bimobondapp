import 'package:bimobondapp/app/posts/domain/entities/toggle_like_params.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class ToggleLikeCommentUsecase implements UseCase<bool, ToggleLikeParams> {
  final PostsRepository repository;

  ToggleLikeCommentUsecase(this.repository);

  @override
  Future<Either<Failure, bool>> call(ToggleLikeParams params) async {
    return await repository.toggleLikeComment(
      params.id,
      liked: params.liked,
    );
  }
}
