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
      receiverId: params.receiverId,
      postId: params.postId,
      auctionId: params.auctionId,
      liveId: params.liveId,
      message: params.message,
    );
  }
}

class SendGiftParams extends Equatable {
  const SendGiftParams({
    required this.giftId,
    required this.receiverId,
    this.postId,
    this.auctionId,
    this.liveId,
    this.message,
  });

  final String giftId;
  /// Required by API; overridden to host for live/auction on the server.
  final String receiverId;
  final String? postId;
  final String? auctionId;
  final String? liveId;
  final String? message;

  @override
  List<Object?> get props =>
      [giftId, receiverId, postId, auctionId, liveId, message];
}
