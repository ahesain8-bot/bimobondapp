import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_group_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetGiftsParams extends Equatable {
  const GetGiftsParams({this.groupId, this.groupSlug});

  final String? groupId;
  final String? groupSlug;

  @override
  List<Object?> get props => [groupId, groupSlug];
}

abstract class GiftsRepository {
  Future<Either<Failure, List<GiftGroupEntity>>> getGiftGroups();
  Future<Either<Failure, List<GiftEntity>>> getGifts({
    String? groupId,
    String? groupSlug,
  });
  Future<Either<Failure, GiftInventoryEntity>> getInventory();
  Future<Either<Failure, GiftInventoryEntity>> purchaseGift({
    required String giftId,
    int quantity,
  });
  Future<Either<Failure, GiftInventoryEntity?>> sendGift({
    required String giftId,
    required String receiverId,
    int quantity = 1,
    String? postId,
    String? auctionId,
    String? liveId,
    String? message,
  });
}
