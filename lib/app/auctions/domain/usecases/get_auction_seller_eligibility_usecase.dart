import 'package:bimobondapp/app/auctions/domain/entities/auction_seller_eligibility_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetAuctionSellerEligibilityUseCase
    implements UseCase<AuctionSellerEligibilityEntity, NoParams> {
  GetAuctionSellerEligibilityUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionSellerEligibilityEntity>> call(NoParams params) {
    return repository.getSellerEligibility();
  }
}
