import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class AuctionPricingPreviewParams extends Equatable {
  const AuctionPricingPreviewParams({
    this.targetCoins,
    this.targetPrice,
  }) : assert(
          (targetCoins != null) != (targetPrice != null),
          'Provide exactly one of targetCoins or targetPrice',
        );

  /// Convenience for coin-based preview (wallet / coins hub).
  const AuctionPricingPreviewParams.coins(int coins)
      : targetCoins = coins,
        targetPrice = null;

  final int? targetCoins;
  final double? targetPrice;

  @override
  List<Object?> get props => [targetCoins, targetPrice];
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
      targetPrice: params.targetPrice,
    );
  }
}
