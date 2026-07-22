import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetMyAuctionsUseCase
    implements UseCase<MyAuctionsPage, GetMyAuctionsParams> {
  GetMyAuctionsUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, MyAuctionsPage>> call(GetMyAuctionsParams params) {
    return repository.getMyAuctions(
      type: params.type,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetMyAuctionsParams extends Equatable {
  const GetMyAuctionsParams({
    this.type = 'all',
    this.page = 1,
    this.limit = 10,
  });

  /// hosted | won | all
  final String type;
  final int page;
  final int limit;

  @override
  List<Object?> get props => [type, page, limit];
}
