import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';

class ReportPostUseCase implements UseCase<void, ReportPostParams> {
  ReportPostUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, void>> call(ReportPostParams params) {
    return repository.reportPost(
      params.postId,
      reason: params.reason,
      details: params.details,
    );
  }
}

class ReportPostParams extends Equatable {
  const ReportPostParams({
    required this.postId,
    required this.reason,
    this.details,
  });

  final String postId;
  final String reason;
  final String? details;

  @override
  List<Object?> get props => [postId, reason, details];
}
