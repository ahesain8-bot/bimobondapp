import '../../../../core/services/live_operation_guard.dart';

/// One unresolved checkout blocks further payments for this account, even if
/// another screen changes the coupon, items or LIVE. No replay is permitted
/// until the backend supplies an authoritative order lookup/reconciliation.
class CheckoutPaymentGuard {
  CheckoutPaymentGuard(this.operations);
  static final shared = CheckoutPaymentGuard(LiveOperationGuard.shared);
  final LiveOperationGuard operations;

  Future<T> run<T>({
    required String Function() userId,
    required Map<String, dynamic> body,
    required Future<T> Function() send,
  }) async {
    try {
      return await operations.run(
        userId: userId,
        liveId: 'shop',
        operation: 'checkout',
        entityId: 'payment',
        context: body,
        retainSuccess: false,
        send: send,
      );
    } on LiveOperationNotSent {
      rethrow;
    } on LiveOperationRejected {
      rethrow;
    } catch (_) {
      throw const LiveOperationUnresolved();
    }
  }
}
