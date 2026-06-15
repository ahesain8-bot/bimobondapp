import 'dart:ui';

import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:equatable/equatable.dart';

class GiftEntity extends Equatable {
  const GiftEntity({
    required this.id,
    required this.name,
    required this.icon,
    required this.priceUsd,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String icon;
  final double priceUsd;
  final String? imageUrl;

  bool get hasNetworkIcon {
    final clean = icon.trim();
    if (clean.startsWith('assets/') || clean.startsWith('packages/')) {
      return false;
    }
    return clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('/') ||
        clean.contains('/') ||
        clean.contains(r'\');
  }

  String priceUsdLabel(Locale locale) {
    final amount = priceUsd == priceUsd.roundToDouble()
        ? priceUsd.round().toString()
        : priceUsd.toStringAsFixed(2);
    return '\$${LocaleFormatUtils.localizeDigits(amount, locale)}';
  }

  @override
  List<Object?> get props => [id, name, icon, priceUsd, imageUrl];
}

class GiftInventoryItemEntity extends Equatable {
  const GiftInventoryItemEntity({
    required this.giftId,
    required this.quantity,
    this.gift,
  });

  final String giftId;
  final int quantity;
  final GiftEntity? gift;

  @override
  List<Object?> get props => [giftId, quantity, gift];
}

class GiftInventoryEntity extends Equatable {
  const GiftInventoryEntity({
    required this.coinBalance,
    required this.items,
  });

  final int coinBalance;
  final List<GiftInventoryItemEntity> items;

  int quantityFor(String giftId) {
    for (final item in items) {
      if (item.giftId == giftId) return item.quantity;
    }
    return 0;
  }

  @override
  List<Object?> get props => [coinBalance, items];
}
