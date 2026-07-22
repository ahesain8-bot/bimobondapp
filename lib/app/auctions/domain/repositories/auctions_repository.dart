import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_fulfillment_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_seller_eligibility_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/create_auction_input.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class MyAuctionsPage {
  const MyAuctionsPage({
    required this.auctions,
    required this.total,
    required this.page,
    required this.lastPage,
  });

  final List<AuctionDetailsEntity> auctions;
  final int total;
  final int page;
  final int lastPage;
}

abstract class AuctionsRepository {
  Future<Either<Failure, AuctionDetailsEntity>> getAuctionDetails(
    String auctionId,
  );

  Future<Either<Failure, List<AuctionDetailsEntity>>> getActiveAuctions();

  Future<Either<Failure, AuctionPricingPreviewEntity>> getPricingPreview({
    int? targetCoins,
    double? targetPrice,
  });

  Future<Either<Failure, AuctionSellerEligibilityEntity>> getSellerEligibility();

  Future<Either<Failure, AuctionDetailsEntity>> createAuction(
    CreateAuctionInput input,
  );

  Future<Either<Failure, AuctionDetailsEntity>> updateAuction(
    String auctionId,
    Map<String, dynamic> data,
  );

  Future<Either<Failure, AuctionDetailsEntity>> cancelAuction(String auctionId);

  Future<Either<Failure, MyAuctionsPage>> getMyAuctions({
    String type = 'all',
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, AuctionFulfillmentEntity>> getFulfillment(
    String auctionId,
  );

  Future<Either<Failure, AuctionFulfillmentEntity>> shipFulfillment(
    String auctionId, {
    String? trackingNumber,
    String? shippingNote,
  });

  Future<Either<Failure, AuctionFulfillmentEntity>> receiveFulfillment(
    String auctionId,
  );

  Future<Either<Failure, AuctionFulfillmentEntity>> acceptFulfillment(
    String auctionId,
  );

  Future<Either<Failure, AuctionFulfillmentEntity>> disputeFulfillment(
    String auctionId, {
    String? reason,
  });
}
