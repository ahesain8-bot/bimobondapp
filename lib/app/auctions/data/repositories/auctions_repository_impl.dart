import 'package:bimobondapp/app/auctions/data/datasources/auctions_remote_data_source.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
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
      final details = await remoteDataSource.getAuctionDetails(auctionId);
      return Right(details);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, AuctionPricingPreviewEntity>> getPricingPreview({
    required int targetCoins,
    double startingPrice = 0,
  }) async {
    try {
      final preview = await remoteDataSource.getPricingPreview(
        targetCoins: targetCoins,
        startingPrice: startingPrice,
      );
      return Right(preview);
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
