import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_share_result.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';

class SharePostUseCase implements UseCase<PostShareResult, SharePostParams> {
  SharePostUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, PostShareResult>> call(SharePostParams params) {
    return repository.sharePost(params.postId, channel: params.channel);
  }
}

class SharePostParams extends Equatable {
  const SharePostParams({
    required this.postId,
    this.channel = 'EXTERNAL',
  });

  final String postId;
  final String channel;

  @override
  List<Object?> get props => [postId, channel];
}
