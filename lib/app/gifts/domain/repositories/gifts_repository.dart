import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class GiftsRepository {
  Future<Either<Failure, List<GiftEntity>>> getGifts();
  Future<Either<Failure, GiftInventoryEntity>> getInventory();
  Future<Either<Failure, GiftInventoryEntity>> purchaseGift({
    required String giftId,
    int quantity,
  });
  Future<Either<Failure, GiftInventoryEntity?>> sendGift({
    required String giftId,
    int quantity,
    String? postId,
    String? receiverId,
    String? auctionId,
  });
}
