import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class CancelAuctionUseCase
    implements UseCase<AuctionDetailsEntity, CancelAuctionParams> {
  CancelAuctionUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionDetailsEntity>> call(CancelAuctionParams params) {
    return repository.cancelAuction(params.auctionId);
  }
}

class CancelAuctionParams extends Equatable {
  const CancelAuctionParams(this.auctionId);

  final String auctionId;

  @override
  List<Object?> get props => [auctionId];
}
