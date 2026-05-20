import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetGiftsUseCase implements UseCase<List<GiftEntity>, NoParams> {
  GetGiftsUseCase(this.repository);

  final GiftsRepository repository;

  @override
  Future<Either<Failure, List<GiftEntity>>> call(NoParams params) {
    return repository.getGifts();
  }
}
