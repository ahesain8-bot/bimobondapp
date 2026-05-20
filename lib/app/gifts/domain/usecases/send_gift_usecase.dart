import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class SendGiftUseCase implements UseCase<GiftInventoryEntity?, SendGiftParams> {
  SendGiftUseCase(this.repository);

  final GiftsRepository repository;

  @override
  Future<Either<Failure, GiftInventoryEntity?>> call(SendGiftParams params) {
    return repository.sendGift(
      giftId: params.giftId,
      quantity: params.quantity,
      postId: params.postId,
      receiverId: params.receiverId,
      auctionId: params.auctionId,
    );
  }
}

class SendGiftParams extends Equatable {
  const SendGiftParams({
    required this.giftId,
    this.quantity = 1,
    this.postId,
    this.receiverId,
    this.auctionId,
  });

  final String giftId;
  final int quantity;
  final String? postId;
  final String? receiverId;
  final String? auctionId;

  @override
  List<Object?> get props => [giftId, quantity, postId, receiverId, auctionId];
}
