import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_coin_package.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_package_card.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class WalletPackagesGrid extends StatelessWidget {
  const WalletPackagesGrid({
    required this.packages,
    required this.selectedIndex,
    required this.onPackageSelected,
    super.key,
  });

  final List<WalletCoinPackage> packages;
  final int selectedIndex;
  final ValueChanged<int> onPackageSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: AppSizes.p10,
        mainAxisSpacing: AppSizes.p10,
      ),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        return WalletPackageCard(
          package: packages[index],
          selected: selectedIndex == index,
          onTap: () => onPackageSelected(index),
        );
      },
    );
  }
}
