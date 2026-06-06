import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/update_post_params.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class UpdatePostUsecase implements UseCase<PostEntity, UpdatePostParams> {
  final PostsRepository repository;

  UpdatePostUsecase(this.repository);

  @override
  Future<Either<Failure, PostEntity>> call(UpdatePostParams params) async {
    return repository.updatePost(
      params.postId,
      description: params.description,
      categoryId: params.categoryId,
      privacyStatus: params.privacyStatus,
    );
  }
}
