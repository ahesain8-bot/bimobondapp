import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/domain/repositories/wallets_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetMyWalletUseCase implements UseCase<WalletEntity, NoParams> {
  GetMyWalletUseCase(this.repository);

  final WalletsRepository repository;

  @override
  Future<Either<Failure, WalletEntity>> call(NoParams params) {
    return repository.getMyWallet();
  }
}

class GetCoinPackagesUseCase implements UseCase<List<CoinPackageEntity>, NoParams> {
  GetCoinPackagesUseCase(this.repository);

  final WalletsRepository repository;

  @override
  Future<Either<Failure, List<CoinPackageEntity>>> call(NoParams params) {
    return repository.getPackages();
  }
}

class PurchaseCoinsParams extends Equatable {
  const PurchaseCoinsParams({
    required this.packageId,
    required this.provider,
    required this.providerTxId,
  });

  final String packageId;
  final String provider;
  final String providerTxId;

  @override
  List<Object?> get props => [packageId, provider, providerTxId];
}

class PurchaseCoinsUseCase
    implements UseCase<CoinPurchaseResultEntity, PurchaseCoinsParams> {
  PurchaseCoinsUseCase(this.repository);

  final WalletsRepository repository;

  @override
  Future<Either<Failure, CoinPurchaseResultEntity>> call(
    PurchaseCoinsParams params,
  ) {
    return repository.purchasePackage(
      packageId: params.packageId,
      provider: params.provider,
      providerTxId: params.providerTxId,
    );
  }
}

class TopUpWalletParams extends Equatable {
  const TopUpWalletParams({
    required this.paidPrice,
    required this.provider,
    required this.providerTxId,
    this.currencyCode = 'USD',
  });

  final double paidPrice;
  final String provider;
  final String providerTxId;
  final String currencyCode;

  @override
  List<Object?> get props => [paidPrice, provider, providerTxId, currencyCode];
}

class TopUpWalletUseCase
    implements UseCase<CoinPurchaseResultEntity, TopUpWalletParams> {
  TopUpWalletUseCase(this.repository);

  final WalletsRepository repository;

  @override
  Future<Either<Failure, CoinPurchaseResultEntity>> call(
    TopUpWalletParams params,
  ) {
    return repository.topUp(
      paidPrice: params.paidPrice,
      provider: params.provider,
      providerTxId: params.providerTxId,
      currencyCode: params.currencyCode,
    );
  }
}
