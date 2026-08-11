import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/app/shop/domain/services/payment_service.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class CoinsPaymentService implements PaymentService {
  CoinsPaymentService({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;

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
