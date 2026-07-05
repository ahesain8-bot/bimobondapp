import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class AuctionPricingPreviewParams extends Equatable {
  const AuctionPricingPreviewParams({
    required this.targetCoins,
    this.startingPrice = 0,
  });

  final int targetCoins;
  final double startingPrice;

  @override
  List<Object?> get props => [targetCoins, startingPrice];
}

class GetAuctionPricingPreviewUseCase
    implements UseCase<AuctionPricingPreviewEntity, AuctionPricingPreviewParams> {
  GetAuctionPricingPreviewUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionPricingPreviewEntity>> call(
    AuctionPricingPreviewParams params,
  ) {
    return repository.getPricingPreview(
      targetCoins: params.targetCoins,
      startingPrice: params.startingPrice,
    );
  }
}
