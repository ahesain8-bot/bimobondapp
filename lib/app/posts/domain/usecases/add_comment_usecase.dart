import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class AddCommentUsecase implements UseCase<CommentEntity, AddCommentParams> {
  final PostsRepository repository;

  AddCommentUsecase(this.repository);

  @override
  Future<Either<Failure, CommentEntity>> call(AddCommentParams params) async {
    return await repository.addComment(params.postId, content: params.content, parentId: params.parentId);
  }
}

class AddCommentParams {
  final String postId;
  final String content;
  final String? parentId;

  AddCommentParams({required this.postId, required this.content, this.parentId});
}
