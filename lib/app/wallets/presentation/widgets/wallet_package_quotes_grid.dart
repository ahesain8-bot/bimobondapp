import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/presentation/widgets/wallet_package_quote_card.dart';
import 'package:flutter/material.dart';

class WalletPackageQuotesGrid extends StatelessWidget {
  const WalletPackageQuotesGrid({
    required this.packages,
    required this.selectedIndex,
    required this.onPackageSelected,
    super.key,
  });

  final List<CoinPackageEntity> packages;
  final int selectedIndex;
  final ValueChanged<int> onPackageSelected;

  @override
  Widget build(BuildContext context) {
    final activePackages =
        packages.where((pack) => pack.isActive).toList(growable: false);

    if (activePackages.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: activePackages.length,
      itemBuilder: (context, index) {
        final pack = activePackages[index];
        final sourceIndex = packages.indexOf(pack);
        return WalletPackageQuoteCard(
          package: pack,
          selected: selectedIndex == sourceIndex,
          onTap: () => onPackageSelected(sourceIndex),
        );
      },
    );
  }
}
