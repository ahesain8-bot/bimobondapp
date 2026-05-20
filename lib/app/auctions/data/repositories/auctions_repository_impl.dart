import 'package:bimobondapp/app/auctions/data/datasources/auctions_remote_data_source.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class AuctionsRepositoryImpl implements AuctionsRepository {
  AuctionsRepositoryImpl({required this.remoteDataSource});

  final AuctionsRemoteDataSource remoteDataSource;

  Failure _mapException(Object e) {
    if (e is ServerException) {
      return ServerFailure(e.message ?? 'Something went wrong');
    }
    if (e is UnauthorizedException) {
      return UnauthorizedFailure(e.message ?? 'Unauthorized');
    }
    return ServerFailure(e.toString());
  }

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
}
