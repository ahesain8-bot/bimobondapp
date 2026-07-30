import 'package:bimobondapp/app/gifts/domain/entities/gift_group_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetGiftGroupsUseCase
    implements UseCase<List<GiftGroupEntity>, NoParams> {
  GetGiftGroupsUseCase(this.repository);

  final GiftsRepository repository;

  @override
  Future<Either<Failure, List<GiftGroupEntity>>> call(NoParams params) {
    return repository.getGiftGroups();
  }
}
