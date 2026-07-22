import 'package:bimobondapp/app/auctions/data/datasources/auctions_remote_data_source.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_fulfillment_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_seller_eligibility_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/create_auction_input.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class AuctionsRepositoryImpl implements AuctionsRepository {
  AuctionsRepositoryImpl({required this.remoteDataSource});

  final AuctionsRemoteDataSource remoteDataSource;

  Failure _mapException(Object e) => FailureMapper.from(e);

  @override
  Future<Either<Failure, AuctionDetailsEntity>> getAuctionDetails(
    String auctionId,
  ) async {
    try {
      return Right(await remoteDataSource.getAuctionDetails(auctionId));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, List<AuctionDetailsEntity>>> getActiveAuctions() async {
    try {
      return Right(await remoteDataSource.getActiveAuctions());
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionPricingPreviewEntity>> getPricingPreview({
    int? targetCoins,
    double? targetPrice,
  }) async {
    try {
      return Right(
        await remoteDataSource.getPricingPreview(
          targetCoins: targetCoins,
          targetPrice: targetPrice,
        ),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionSellerEligibilityEntity>>
      getSellerEligibility() async {
    try {
      return Right(await remoteDataSource.getSellerEligibility());
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionDetailsEntity>> createAuction(
    CreateAuctionInput input,
  ) async {
    try {
      return Right(await remoteDataSource.createAuction(input));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionDetailsEntity>> updateAuction(
    String auctionId,
    Map<String, dynamic> data,
  ) async {
    try {
      return Right(await remoteDataSource.updateAuction(auctionId, data));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionDetailsEntity>> cancelAuction(
    String auctionId,
  ) async {
    try {
      return Right(await remoteDataSource.cancelAuction(auctionId));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, MyAuctionsPage>> getMyAuctions({
    String type = 'all',
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final result = await remoteDataSource.getMyAuctions(
        type: type,
        page: page,
        limit: limit,
      );
      return Right(
        MyAuctionsPage(
          auctions: result.auctions,
          total: result.total,
          page: result.page,
          lastPage: result.lastPage,
        ),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> getFulfillment(
    String auctionId,
  ) async {
    try {
      return Right(await remoteDataSource.getFulfillment(auctionId));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> shipFulfillment(
    String auctionId, {
    String? trackingNumber,
    String? shippingNote,
  }) async {
    try {
      return Right(
        await remoteDataSource.shipFulfillment(
          auctionId,
          trackingNumber: trackingNumber,
          shippingNote: shippingNote,
        ),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> receiveFulfillment(
    String auctionId,
  ) async {
    try {
      return Right(await remoteDataSource.receiveFulfillment(auctionId));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> acceptFulfillment(
    String auctionId,
  ) async {
    try {
      return Right(await remoteDataSource.acceptFulfillment(auctionId));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> disputeFulfillment(
    String auctionId, {
    String? reason,
  }) async {
    try {
      return Right(
        await remoteDataSource.disputeFulfillment(
          auctionId,
          reason: reason,
        ),
      );
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
