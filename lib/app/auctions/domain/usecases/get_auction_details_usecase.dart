import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetAuctionDetailsUseCase
    implements UseCase<AuctionDetailsEntity, GetAuctionDetailsParams> {
  GetAuctionDetailsUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionDetailsEntity>> call(
    GetAuctionDetailsParams params,
  ) {
    return repository.getAuctionDetails(params.auctionId);
  }
}

class GetAuctionDetailsParams extends Equatable {
  const GetAuctionDetailsParams({required this.auctionId});

  final String auctionId;

  @override
  List<Object?> get props => [auctionId];
}
