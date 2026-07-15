import 'package:bimobondapp/app/search/domain/repositories/search_history_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class DeleteSearchHistoryUseCase
    implements UseCase<void, DeleteSearchHistoryParams> {
  DeleteSearchHistoryUseCase(this.repository);

  final SearchHistoryRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteSearchHistoryParams params) {
    return repository.deleteHistory(params.id);
  }
}

class DeleteSearchHistoryParams {
  const DeleteSearchHistoryParams({required this.id});

  final String id;
}
