import 'package:bimobondapp/app/wallets/data/datasources/wallets_remote_data_source.dart';
import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/domain/repositories/wallets_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class WalletsRepositoryImpl implements WalletsRepository {
  WalletsRepositoryImpl({required this.remoteDataSource});

  final WalletsRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, WalletEntity>> getMyWallet() async {
    try {
      final wallet = await remoteDataSource.getMyWallet();
      return Right(wallet);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<CoinPackageEntity>>> getPackages() async {
    try {
      final packages = await remoteDataSource.getPackages();
      return Right(packages);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CoinPurchaseResultEntity>> purchasePackage({
    required String packageId,
    required String provider,
    required String providerTxId,
  }) async {
    try {
      final result = await remoteDataSource.purchasePackage(
        packageId: packageId,
        provider: provider,
        providerTxId: providerTxId,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CoinPurchaseResultEntity>> topUp({
    required double paidPrice,
    required String provider,
    required String providerTxId,
    String currencyCode = 'USD',
  }) async {
    try {
      final result = await remoteDataSource.topUp(
        paidPrice: paidPrice,
        provider: provider,
        providerTxId: providerTxId,
        currencyCode: currencyCode,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
