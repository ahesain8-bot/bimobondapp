import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetSuggestionsUseCase
    implements UseCase<List<UserSuggestionEntity>, GetSuggestionsParams> {
  GetSuggestionsUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, List<UserSuggestionEntity>>> call(
    GetSuggestionsParams params,
  ) {
    return repository.getSuggestions(limit: params.limit);
  }
}

class GetSuggestionsParams extends Equatable {
  const GetSuggestionsParams({this.limit = 20});

  final int limit;

  @override
  List<Object?> get props => [limit];
}
