import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetGiftsUseCase implements UseCase<List<GiftEntity>, GetGiftsParams> {
  GetGiftsUseCase(this.repository);

  final GiftsRepository repository;

  @override
  Future<Either<Failure, List<GiftEntity>>> call(GetGiftsParams params) {
    return repository.getGifts(
      groupId: params.groupId,
      groupSlug: params.groupSlug,
    );
  }
}
