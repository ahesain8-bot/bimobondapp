import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_history_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class AddSearchHistoryUseCase
    implements UseCase<SearchHistoryEntity, AddSearchHistoryParams> {
  AddSearchHistoryUseCase(this.repository);

  final SearchHistoryRepository repository;

  @override
  Future<Either<Failure, SearchHistoryEntity>> call(
    AddSearchHistoryParams params,
  ) {
    return repository.addHistory(
      query: params.query,
      category: params.category,
    );
  }
}

class AddSearchHistoryParams {
  const AddSearchHistoryParams({
    required this.query,
    required this.category,
  });

  final String query;
  final String category;
}
