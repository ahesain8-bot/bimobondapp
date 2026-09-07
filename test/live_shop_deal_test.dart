import 'package:bimobondapp/app/shop/data/datasources/shop_remote_data_source.dart';
import 'package:bimobondapp/app/shop/data/models/shop_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feature 18 host side: `PATCH /products/lives/:liveId/items/:productId/deal`
/// (`lives/live-p0-parity.md` §3). The client sends what the host typed and
/// renders what the server returns — it never computes a discount.
void main() {
  group('the deal request body follows the contract', () {
    test('a full deal sends both halves as documented', () {
      final endsAt = DateTime.utc(2026, 9, 5, 18);

      final body = buildLiveProductDealBody(
        flashPriceCoins: 70,
        flashEndsAt: endsAt,
        couponCode: ' LIVE10 ',
        couponOffCoins: 10,
      );

      expect(body, {
        'flashPriceCoins': 70,
        'flashEndsAt': endsAt.toIso8601String(),
        'couponCode': 'LIVE10',
        'couponOffCoins': 10,
      });
    });

    test('a flash deal alone leaves the coupon untouched', () {
      final body = buildLiveProductDealBody(
        flashPriceCoins: 70,
        flashEndsAt: DateTime.utc(2026, 9, 5, 18),
      );

      expect(body.keys, ['flashPriceCoins', 'flashEndsAt']);
    });

    test('clearing sends an explicit null for that half only', () {
      expect(buildLiveProductDealBody(clearFlash: true), {
        'flashPriceCoins': null,
        'flashEndsAt': null,
      });
      expect(buildLiveProductDealBody(clearCoupon: true), {
        'couponCode': null,
        'couponOffCoins': null,
      });
    });

    test('half a deal never becomes a request', () {
      expect(
        () => buildLiveProductDealBody(flashPriceCoins: 70),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => buildLiveProductDealBody(flashEndsAt: DateTime.utc(2026)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => buildLiveProductDealBody(couponCode: 'LIVE10'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => buildLiveProductDealBody(couponOffCoins: 10),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('negative coin amounts and an empty change are refused', () {
      expect(
        () => buildLiveProductDealBody(
          flashPriceCoins: -1,
          flashEndsAt: DateTime.utc(2026),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => buildLiveProductDealBody(couponCode: 'X', couponOffCoins: -5),
        throwsA(isA<ArgumentError>()),
      );
      expect(buildLiveProductDealBody, throwsA(isA<ArgumentError>()));
    });
  });

  group('the bag is read from the server', () {
    test('the documented bag block parses with its units', () {
      final pin = LiveProductPinModel.fromJson({
        'id': 'pin-1',
        'liveId': 'live-1',
        'productId': 'prod-1',
        'product': {'id': 'prod-1', 'title': 'Mug', 'priceCoins': 100},
        'bag': {
          'basePriceCoins': 100,
          'livePriceCoins': 70,
          'flashActive': true,
          'hasCoupon': true,
          'dealApplied': 'flash',
          'soldCount': 3,
        },
      });

      expect(pin.bag!.basePriceCoins, 100);
      expect(pin.bag!.livePriceCoins, 70);
      expect(pin.bag!.flashActive, isTrue);
      expect(pin.bag!.dealApplied, 'flash');
      expect(pin.bag!.soldCount, 3);
    });

    test('an incomplete bag is dropped instead of being half-priced', () {
      final pin = LiveProductPinModel.fromJson({
        'id': 'pin-1',
        'liveId': 'live-1',
        'productId': 'prod-1',
        'product': {'id': 'prod-1', 'title': 'Mug', 'priceCoins': 100},
        'bag': {'basePriceCoins': 100, 'flashActive': true},
      });

      expect(pin.bag, isNull);
    });
  });
}
