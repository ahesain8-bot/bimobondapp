import 'package:bimobondapp/app/gifts/data/datasources/gifts_remote_data_source.dart';
import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/app/wallets/domain/repositories/wallets_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class GiftsRepositoryImpl implements GiftsRepository {
  GiftsRepositoryImpl({
    required this.remoteDataSource,
    required this.walletsRepository,
  });

  final GiftsRemoteDataSource remoteDataSource;
  final WalletsRepository walletsRepository;

  Failure _mapException(Object e) => FailureMapper.from(e);

  @override
  Future<Either<Failure, List<GiftEntity>>> getGifts() async {
    try {
      final gifts = await remoteDataSource.getGifts();
      return Right(gifts);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  Future<int?> _fetchWalletBalance() async {
    final result = await walletsRepository.getMyWallet();
    return result.fold((_) => null, (wallet) => wallet.balanceCoins);
  }

  Future<GiftInventoryModel> _enrichWithWalletBalance(
    GiftInventoryModel inventory,
  ) async {
    final walletBalance = await _fetchWalletBalance();
    if (walletBalance == null) return inventory;

    final balance = inventory.balanceCoins > 0
        ? inventory.balanceCoins
        : walletBalance;
    return GiftInventoryModel(balanceCoins: balance, items: inventory.items);
  }

  @override
  Future<Either<Failure, GiftInventoryEntity>> getInventory() async {
    try {
      final inventory = await remoteDataSource.getInventory();
      final enriched = await _enrichWithWalletBalance(inventory);
      return Right(enriched);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, GiftInventoryEntity>> purchaseGift({
    required String giftId,
    int quantity = 1,
  }) async {
    try {
      final inventory = await remoteDataSource.purchaseGift(
        giftId: giftId,
        quantity: quantity,
      );
      final enriched = await _enrichWithWalletBalance(inventory);
      return Right(enriched);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, GiftInventoryEntity?>> sendGift({
    required String giftId,
    required String receiverId,
    String? postId,
    String? auctionId,
    String? liveId,
    String? message,
  }) async {
    try {
      final inventory = await remoteDataSource.sendGift(
        giftId: giftId,
        receiverId: receiverId,
        postId: postId,
        auctionId: auctionId,
        liveId: liveId,
        message: message,
      );
      return Right(inventory);
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
