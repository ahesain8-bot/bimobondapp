import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/app/shop/domain/services/payment_service.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/live_operation_guard.dart';

class CoinsPaymentService implements PaymentService {
  CoinsPaymentService({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;

  @override
  Future<bool> hasUnresolvedPayment() async {
    final account = FirebaseAuth.instance.currentUser?.uid;
    if (account == null) return false;
    final record = await LiveOperationGuard.shared.read(userId: account,
      liveId: 'shop', operation: 'checkout', entityId: 'payment');
    return record.outcome == LiveOperationOutcome.unknown || record.outcome == LiveOperationOutcome.confirmed;
  }

  @override
  Future<Either<Failure, ProductOrderEntity>> pay({
    required List<CheckoutItemInput> items,
    required ProductPaymentMethod method,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
    ShippingAddressInput? shippingAddress,
    String? couponCode,
    String? liveId,
    String? postId,
    String? idempotencyKey,
  }) =>
      _repository.checkout(
        items: items,
        paymentMethod: method,
        giftPayments: giftPayments,
        shippingAddress: shippingAddress,
        couponCode: couponCode,
        liveId: liveId,
        postId: postId,
        idempotencyKey: idempotencyKey,
      );
}
