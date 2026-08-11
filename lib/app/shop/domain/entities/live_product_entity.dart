import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

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
  });

  final String id;
  final String liveId;
  final String productId;
  final ProductEntity product;
  final int pinOrder;
  final bool isPinned;
  final DateTime? pinnedAt;

  @override
  List<Object?> get props =>
      [id, liveId, productId, product, pinOrder, isPinned, pinnedAt];
}
