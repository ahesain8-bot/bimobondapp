import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class PurchaseGiftUseCase
    implements UseCase<GiftInventoryEntity, PurchaseGiftParams> {
  PurchaseGiftUseCase(this.repository);

  final GiftsRepository repository;

  @override
  Future<Either<Failure, GiftInventoryEntity>> call(
    PurchaseGiftParams params,
  ) {
    return repository.purchaseGift(
      giftId: params.giftId,
      quantity: params.quantity,
    );
  }
}

class PurchaseGiftParams extends Equatable {
  const PurchaseGiftParams({
    required this.giftId,
    this.quantity = 1,
  });

  final String giftId;
  final int quantity;

  @override
  List<Object?> get props => [giftId, quantity];
}
