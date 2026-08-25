import 'package:dartz/dartz.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/gift_entity.dart';
import '../repositories/gift_repository.dart';

class SendGiftUseCase {
  final GiftRepository repository;

  SendGiftUseCase(this.repository);

  Future<Either<Failure, GiftSentEntity>> call({
    required String liveId,
    required String giftId,
    int quantity = 1,
    String? receiverId,
  }) {
    return repository.sendGift(
      liveId: liveId,
      giftId: giftId,
      quantity: quantity,
      receiverId: receiverId,
    );
  }
}
