import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_coin_package.dart';
import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';

/// Client-side coin ↔ fiat estimates using the best package rate available.
abstract final class WalletCoinPricing {
  WalletCoinPricing._();

  static double unitPriceFromCoinPackages(List<WalletCoinPackage> packages) {
    return _bestUnitPrice(
      packages.map((p) => (coins: p.coins, price: p.priceUsd)),
    );
  }

  static double unitPriceFromEntities(List<CoinPackageEntity> packages) {
    return _bestUnitPrice(
      packages.map((p) => (coins: p.coinAmount, price: p.price)),
    );
  }

  static double _bestUnitPrice(Iterable<({int coins, double price})> packages) {
    var best = double.infinity;
    for (final pack in packages) {
      if (pack.coins <= 0 || pack.price <= 0) continue;
      final rate = pack.price / pack.coins;
      if (rate < best) best = rate;
    }
    if (!best.isFinite || best <= 0) return 0.0099;
    return best;
  }

  static double priceForCoins(int coins, double unitPrice) {
    if (coins <= 0 || unitPrice <= 0) return 0;
    return (coins * unitPrice * 100).ceil() / 100;
  }

  static int parseCoinsInput(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  static CoinPackageEntity? packageForCoins(
    int coins,
    List<CoinPackageEntity> packages,
  ) {
    for (final pack in packages) {
      if (!pack.isActive) continue;
      if (pack.coinAmount == coins) return pack;
    }
    return null;
  }

  static WalletTopUpQuote resolveQuote(
    int coins,
    List<CoinPackageEntity> packages,
  ) {
    if (coins <= 0) {
      return const WalletTopUpQuote(coins: 0, price: 0);
    }

    final matched = packageForCoins(coins, packages);
    if (matched != null) {
      return WalletTopUpQuote.fromEntity(matched);
    }

    final currency =
        packages.isNotEmpty ? packages.first.currencyCode : 'USD';
    return WalletTopUpQuote.custom(
      coins: coins,
      unitPrice: unitPriceFromEntities(packages),
      currencyCode: currency,
    );
  }
}

class WalletTopUpQuote {
  const WalletTopUpQuote({
    required this.coins,
    required this.price,
    this.currencyCode = 'USD',
    this.packageId,
  });

  final int coins;
  final double price;
  final String currencyCode;
  final String? packageId;

  bool get isValid => coins > 0 && price > 0;

  bool get isPackageQuote => packageId != null && packageId!.isNotEmpty;

  factory WalletTopUpQuote.fromWalletPackage(WalletCoinPackage package) {
    return WalletTopUpQuote(
      coins: package.coins,
      price: package.priceUsd,
      currencyCode: 'USD',
    );
  }

  factory WalletTopUpQuote.fromEntity(CoinPackageEntity package) {
    return WalletTopUpQuote(
      packageId: package.id,
      coins: package.coinAmount,
      price: package.price,
      currencyCode: package.currencyCode,
    );
  }

  factory WalletTopUpQuote.custom({
    required int coins,
    required double unitPrice,
    String currencyCode = 'USD',
  }) {
    return WalletTopUpQuote(
      coins: coins,
      price: WalletCoinPricing.priceForCoins(coins, unitPrice),
      currencyCode: currencyCode,
    );
  }

  factory WalletTopUpQuote.fromPricingPreview(
    AuctionPricingPreviewEntity preview, {
    int? requestedCoins,
  }) {
    final pricing = preview.pricing;
    final coins = requestedCoins ??
        (preview.targetPriceCoins > 0 ? preview.targetPriceCoins : null) ??
        pricing.estimatedHostEarningsCoins ??
        0;
    final price = pricing.estimatedBidderSpendPrice ??
        pricing.targetPrice ??
        (preview.targetPrice > 0 ? preview.targetPrice : 0);
    return WalletTopUpQuote(
      coins: coins,
      price: price,
      currencyCode: preview.currencyCode.isNotEmpty
          ? preview.currencyCode
          : (pricing.currencyCode ?? 'USD'),
    );
  }
}
