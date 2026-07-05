import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class WalletsRepository {
  Future<Either<Failure, WalletEntity>> getMyWallet();
  Future<Either<Failure, List<CoinPackageEntity>>> getPackages();
  Future<Either<Failure, CoinPurchaseResultEntity>> purchasePackage({
    required String packageId,
    required String provider,
    required String providerTxId,
  });
  Future<Either<Failure, CoinPurchaseResultEntity>> topUp({
    required double paidPrice,
    required String provider,
    required String providerTxId,
    String currencyCode = 'USD',
  });
}
