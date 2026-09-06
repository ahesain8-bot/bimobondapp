import 'package:bimobondapp/core/services/live_operation_guard.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/data/services/live_ticket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryOperationStore implements LiveOperationStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  test('ticket status requires the documented root fields', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"data":{"hasTicket":true,"ticketPriceCoins":100}}',
        200,
      ),
    );
    final service = LiveTicketService(
      apiClient: LiveApiClient(httpClient: client),
      userId: () => 'viewer',
      operationGuard: LiveOperationGuard(_MemoryOperationStore()),
    );

    await expectLater(
      service.status('live-1'),
      throwsA(isA<FormatException>()),
    );
    client.close();
  });

  test(
    'purchase posts once and only opens after a confirmed ticket status',
    () async {
      var purchases = 0;
      var statusReads = 0;
      var paid = false;
      final client = MockClient((request) async {
        expect(request.url.path, '/lives/live-1/ticket');
        if (request.method == 'POST') {
          purchases++;
          paid = true;
          return http.Response('{}', 200);
        }
        statusReads++;
        return http.Response('{"hasTicket":$paid,"ticketPriceCoins":100}', 200);
      });
      final service = LiveTicketService(
        apiClient: LiveApiClient(httpClient: client),
        userId: () => 'viewer',
        operationGuard: LiveOperationGuard(_MemoryOperationStore()),
      );

      final access = await service.purchase('live-1');

      expect(access.hasTicket, isTrue);
      expect(access.priceCoins, 100);
      expect(purchases, 1);
      expect(statusReads, 1);
      await expectLater(
        service.purchase('live-1'),
        throwsA(isA<LiveOperationUnresolved>()),
      );
      expect(purchases, 1);
      client.close();
    },
  );
}
