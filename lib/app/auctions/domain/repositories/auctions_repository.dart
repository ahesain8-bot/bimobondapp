import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class AuctionsRepository {
  Future<Either<Failure, AuctionDetailsEntity>> getAuctionDetails(
    String auctionId,
  );

  Future<Either<Failure, AuctionPricingPreviewEntity>> getPricingPreview({
    required int targetCoins,
    double startingPrice = 0,
  });
}
