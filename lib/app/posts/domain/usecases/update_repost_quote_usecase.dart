import 'package:bimobondapp/app/posts/domain/entities/update_repost_quote_params.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class UpdateRepostQuoteUsecase
    implements UseCase<void, UpdateRepostQuoteParams> {
  UpdateRepostQuoteUsecase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, void>> call(UpdateRepostQuoteParams params) {
    return repository.updateRepostQuote(
      params.postId,
      quote: params.quote,
    );
  }
}
