import 'package:equatable/equatable.dart';
import 'checkout_entity.dart';

/// The exact inputs quoted by the server and subsequently submitted for pay.
class CheckoutSnapshot extends Equatable {
  CheckoutSnapshot({
    required List<CheckoutItemInput> items,
    this.method = ProductPaymentMethod.coins,
    String? couponCode,
    this.liveId,
    this.postId,
  }) : items = List.unmodifiable(items),
       couponCode = couponCode?.trim().isNotEmpty == true
           ? couponCode!.trim()
           : null;

  final List<CheckoutItemInput> items;
  final ProductPaymentMethod method;
  final String? couponCode;
  final String? liveId;
  final String? postId;

  @override
  List<Object?> get props => [items, method, couponCode, liveId, postId];
}

/// Discard responses for old inputs, including failures arriving out of order.
class CheckoutQuoteState {
  int _generation = 0;
  CheckoutSnapshot? snapshot;
  CheckoutPreviewEntity? preview;
  bool get canPay => snapshot != null && preview != null;

  int invalidate() {
    snapshot = null;
    preview = null;
    return ++_generation;
  }

  bool isCurrent(int generation) => generation == _generation;

  bool accept(
    int generation,
    CheckoutSnapshot inputs,
    CheckoutPreviewEntity value,
  ) {
    if (!isCurrent(generation)) return false;
    snapshot = inputs;
    preview = value;
    return true;
  }
}
