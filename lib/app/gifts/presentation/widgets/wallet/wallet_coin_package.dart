class WalletCoinPackage {
  const WalletCoinPackage({
    required this.coins,
    required this.priceUsd,
    this.badge,
  });

  final int coins;
  final double priceUsd;
  final String? badge;
}

const List<WalletCoinPackage> walletDefaultPackages = [
  WalletCoinPackage(coins: 100, priceUsd: 0.99),
  WalletCoinPackage(coins: 500, priceUsd: 4.99, badge: 'POPULAR'),
  WalletCoinPackage(coins: 1000, priceUsd: 9.99, badge: 'RECOMMENDED'),
  WalletCoinPackage(coins: 2000, priceUsd: 19.99),
  WalletCoinPackage(coins: 5000, priceUsd: 49.99, badge: 'BEST VALUE'),
  WalletCoinPackage(coins: 10000, priceUsd: 99.99),
];
