import 'package:bimobondapp/app/search/domain/entities/search_result_entity.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class SearchParams extends Equatable {
  const SearchParams({
    required this.q,
    this.tab = SearchApiTab.best,
    this.page = 1,
    this.limit = 20,
  });

  final String q;
  final SearchApiTab tab;
  final int page;
  final int limit;

  @override
  List<Object?> get props => [q, tab, page, limit];
}

class SearchUseCase implements UseCase<SearchResultEntity, SearchParams> {
  SearchUseCase(this.repository);

  final SearchRepository repository;

  @override
  Future<Either<Failure, SearchResultEntity>> call(SearchParams params) {
    return repository.search(
      q: params.q.trim(),
      tab: params.tab,
      page: params.page,
      limit: params.limit,
    );
  }
}
