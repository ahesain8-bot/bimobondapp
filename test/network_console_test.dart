import 'package:bimobondapp/core/network/network_console.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network console redacts credentials in all reported request parts', () {
    final messages = <String?>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = previousDebugPrint);

    final trace = NetworkConsole.start(
      method: 'POST',
      uri: Uri.parse('https://example.test/live?token=do-not-print&page=2'),
      headers: const {
        'Authorization': 'Bearer do-not-print',
        'x-request-id': 'request-7',
      },
      body: const {'title': 'hello', 'refresh_token': 'do-not-print'},
    );
    NetworkConsole.complete(
      trace,
      statusCode: 200,
      body: const {'accessToken': 'do-not-print', 'ok': true},
    );

    final output = messages.join('\n');
    expect(output, isNot(contains('do-not-print')));
    expect(output, contains('<text 9 chars>'));
    expect(output, contains('"ok":true'));
  });
}
