import 'package:equatable/equatable.dart';

class WalletAccountingEntity extends Equatable {
  const WalletAccountingEntity({
    required this.amountCoins,
    required this.action,
    required this.balanceAfterCoins,
    required this.type,
    this.reason,
    this.createdAt,
  });

  final int amountCoins;
  final String action;
  final int balanceAfterCoins;
  final String type;
  final String? reason;
  final DateTime? createdAt;

  @override
  List<Object?> get props =>
      [amountCoins, action, balanceAfterCoins, type, reason, createdAt];
}

class WalletEntity extends Equatable {
  const WalletEntity({
    required this.id,
    required this.userId,
    required this.balanceCoins,
    this.accountings = const [],
  });

  final String id;
  final String userId;
  final int balanceCoins;
  final List<WalletAccountingEntity> accountings;

  @override
  List<Object?> get props => [id, userId, balanceCoins, accountings];
}

class CoinPackageEntity extends Equatable {
  const CoinPackageEntity({
    required this.id,
    required this.name,
    required this.coinAmount,
    required this.price,
    required this.currencyCode,
    this.bonusCoins = 0,
    this.isActive = true,
    this.badge,
  });

  final String id;
  final String name;
  final int coinAmount;
  final double price;
  final String currencyCode;
  final int bonusCoins;
  final bool isActive;
  final String? badge;

  int get totalCoins => coinAmount + bonusCoins;

  @override
  List<Object?> get props =>
      [id, name, coinAmount, price, currencyCode, bonusCoins, isActive, badge];
}

class CoinPurchaseResultEntity extends Equatable {
  const CoinPurchaseResultEntity({
    required this.success,
    required this.newBalanceCoins,
    this.purchaseId,
  });

  final bool success;
  final int newBalanceCoins;
  final String? purchaseId;

  @override
  List<Object?> get props => [success, newBalanceCoins, purchaseId];
}
