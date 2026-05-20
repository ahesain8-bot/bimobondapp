import 'package:bimobondapp/app/gifts/data/datasources/gifts_remote_data_source.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class GiftsRepositoryImpl implements GiftsRepository {
  GiftsRepositoryImpl({required this.remoteDataSource});

  final GiftsRemoteDataSource remoteDataSource;

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
  Future<Either<Failure, List<GiftEntity>>> getGifts() async {
    try {
      final gifts = await remoteDataSource.getGifts();
      return Right(gifts);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, GiftInventoryEntity>> getInventory() async {
    try {
      final inventory = await remoteDataSource.getInventory();
      return Right(inventory);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, GiftInventoryEntity>> purchaseGift({
    required String giftId,
    int quantity = 1,
  }) async {
    try {
      final inventory = await remoteDataSource.purchaseGift(
        giftId: giftId,
        quantity: quantity,
      );
      return Right(inventory);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, GiftInventoryEntity?>> sendGift({
    required String giftId,
    int quantity = 1,
    String? postId,
    String? receiverId,
    String? auctionId,
  }) async {
    try {
      final inventory = await remoteDataSource.sendGift(
        giftId: giftId,
        quantity: quantity,
        postId: postId,
        receiverId: receiverId,
        auctionId: auctionId,
      );
      return Right(inventory);
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
