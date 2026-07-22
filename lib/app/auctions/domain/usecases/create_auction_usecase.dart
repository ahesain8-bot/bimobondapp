import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/create_auction_input.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class CreateAuctionUseCase
    implements UseCase<AuctionDetailsEntity, CreateAuctionInput> {
  CreateAuctionUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionDetailsEntity>> call(CreateAuctionInput params) {
    return repository.createAuction(params);
  }
}
