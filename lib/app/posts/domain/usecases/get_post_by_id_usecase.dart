import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetPostByIdUseCase implements UseCase<PostEntity, String> {
  final PostsRepository repository;

  GetPostByIdUseCase(this.repository);

  @override
  Future<Either<Failure, PostEntity>> call(String postId) async {
    return repository.getPostById(postId);
  }
}
