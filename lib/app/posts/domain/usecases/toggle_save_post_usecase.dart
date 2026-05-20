import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class ToggleSavePostUsecase implements UseCase<bool, String> {
  final PostsRepository repository;

  ToggleSavePostUsecase(this.repository);

  @override
  Future<Either<Failure, bool>> call(String postId) async {
    return await repository.toggleSave(postId);
  }
}
