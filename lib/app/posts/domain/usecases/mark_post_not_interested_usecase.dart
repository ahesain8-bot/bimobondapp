import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';

class MarkPostNotInterestedUseCase
    implements UseCase<void, MarkPostNotInterestedParams> {
  MarkPostNotInterestedUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, void>> call(MarkPostNotInterestedParams params) {
    return repository.markPostNotInterested(params.postId);
  }
}

class MarkPostNotInterestedParams extends Equatable {
  const MarkPostNotInterestedParams(this.postId);

  final String postId;

  @override
  List<Object?> get props => [postId];
}
