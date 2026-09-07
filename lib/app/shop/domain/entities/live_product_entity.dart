import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

/// Server-calculated price context for a product in one LIVE bag.
///
/// The client only displays these values; checkout preview remains the source
/// of truth for the final flash/coupon order and total.
class LiveProductBagEntity extends Equatable {
  const LiveProductBagEntity({
    required this.basePriceCoins,
    required this.livePriceCoins,
    required this.flashActive,
    required this.hasCoupon,
    required this.soldCount,
    this.dealApplied,
  });

  final int basePriceCoins;
  final int livePriceCoins;
  final bool flashActive;
  final bool hasCoupon;
  final String? dealApplied;
  final int soldCount;

  @override
  List<Object?> get props => [
    basePriceCoins,
    livePriceCoins,
    flashActive,
    hasCoupon,
    dealApplied,
    soldCount,
  ];
}

/// Product pinned/listed on a live stream gallery.
class LiveProductPinEntity extends Equatable {
  const LiveProductPinEntity({
    required this.id,
    required this.liveId,
    required this.productId,
    required this.product,
    this.pinOrder = 0,
    this.isPinned = false,
    this.pinnedAt,
    this.bag,
  });

  final String id;
  final String liveId;
  final String productId;
  final ProductEntity product;
  final int pinOrder;
  final bool isPinned;
  final DateTime? pinnedAt;
  final LiveProductBagEntity? bag;

  @override
  List<Object?> get props => [
    id,
    liveId,
    productId,
    product,
    pinOrder,
    isPinned,
    pinnedAt,
    bag,
  ];
}
