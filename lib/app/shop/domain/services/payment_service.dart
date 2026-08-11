import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class PaymentService {
  Future<Either<Failure, ProductOrderEntity>> pay({
    required List<CheckoutItemInput> items,
    required ProductPaymentMethod method,
    List<CheckoutGiftPaymentInput> giftPayments = const [],
    ShippingAddressInput? shippingAddress,
    String? couponCode,
    String? liveId,
    String? postId,
    String? idempotencyKey,
  });
}
