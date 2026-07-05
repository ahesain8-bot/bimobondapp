import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';

class WalletAccountingModel extends WalletAccountingEntity {
  const WalletAccountingModel({
    required super.amountCoins,
    required super.action,
    required super.balanceAfterCoins,
    required super.type,
    super.reason,
    super.createdAt,
  });

  factory WalletAccountingModel.fromJson(Map<String, dynamic> json) {
    return WalletAccountingModel(
      amountCoins: _readInt(
        json['amountCoins'] ?? json['amountUsd'] ?? json['amount'] ?? 0,
      ),
      action: (json['action'] ?? '').toString(),
      balanceAfterCoins: _readInt(
        json['balanceAfterCoins'] ??
            json['balanceAfter'] ??
            json['balanceAfterUsd'] ??
            0,
      ),
      type: (json['type'] ?? '').toString(),
      reason: json['reason']?.toString(),
      createdAt: _readDate(json['createdAt']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class WalletModel extends WalletEntity {
  const WalletModel({
    required super.id,
    required super.userId,
    required super.balanceCoins,
    super.accountings,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return WalletModel.fromJson(data);
    }

    final accountingsRaw = json['accountings'] ?? json['ledger'] ?? json['history'];
    final accountings = <WalletAccountingModel>[];
    if (accountingsRaw is List) {
      for (final entry in accountingsRaw) {
        if (entry is Map) {
          accountings.add(
            WalletAccountingModel.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }

    return WalletModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      balanceCoins: WalletAccountingModel._readInt(
        json['balanceCoins'] ??
            json['balanceUsd'] ??
            json['balance'] ??
            json['coinBalance'] ??
            0,
      ),
      accountings: accountings,
    );
  }
}

class CoinPackageModel extends CoinPackageEntity {
  const CoinPackageModel({
    required super.id,
    required super.name,
    required super.coinAmount,
    required super.price,
    required super.currencyCode,
    super.bonusCoins,
    super.isActive,
    super.badge,
  });

  factory CoinPackageModel.fromJson(Map<String, dynamic> json) {
    final coinAmount = WalletAccountingModel._readInt(
      json['coinAmount'] ??
          json['amountUsd'] ??
          json['coins'] ??
          json['amount'] ??
          0,
    );
    final price = _readDouble(
      json['price'] ?? json['priceUsd'] ?? json['fiatPriceUsd'] ?? 0,
    );

    return CoinPackageModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Pack').toString(),
      coinAmount: coinAmount,
      price: price,
      currencyCode: (json['currencyCode'] ?? json['currency'] ?? 'USD')
          .toString()
          .toUpperCase(),
      bonusCoins: WalletAccountingModel._readInt(json['bonusCoins'] ?? 0),
      isActive: json['isActive'] != false,
      badge: json['badge']?.toString(),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class CoinPurchaseResultModel extends CoinPurchaseResultEntity {
  const CoinPurchaseResultModel({
    required super.success,
    required super.newBalanceCoins,
    super.purchaseId,
  });

  factory CoinPurchaseResultModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return CoinPurchaseResultModel.fromJson(data);
    }

    return CoinPurchaseResultModel(
      success: json['success'] == true || json['success'] == 'true',
      newBalanceCoins: WalletAccountingModel._readInt(
        json['newBalanceCoins'] ??
            json['newBalance'] ??
            json['balanceCoins'] ??
            0,
      ),
      purchaseId: json['purchaseId']?.toString(),
    );
  }
}
