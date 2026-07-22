import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetActiveAuctionsUseCase
    implements UseCase<List<AuctionDetailsEntity>, NoParams> {
  GetActiveAuctionsUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, List<AuctionDetailsEntity>>> call(NoParams params) {
    return repository.getActiveAuctions();
  }
}
