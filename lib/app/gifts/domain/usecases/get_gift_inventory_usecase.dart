import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetGiftInventoryUseCase
    implements UseCase<GiftInventoryEntity, NoParams> {
  GetGiftInventoryUseCase(this.repository);

  final GiftsRepository repository;

  @override
  Future<Either<Failure, GiftInventoryEntity>> call(NoParams params) {
    return repository.getInventory();
  }
}
