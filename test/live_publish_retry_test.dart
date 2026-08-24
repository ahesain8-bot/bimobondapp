import 'package:flutter_test/flutter_test.dart';

/// Mirrors the backoff the camera-open loop applies, so the cost of a retry
/// budget can be asserted without opening a camera.
Duration backoffFor(int maxAttempts) {
  var total = Duration.zero;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (attempt < maxAttempts - 1) {
      total += Duration(milliseconds: 250 * (attempt + 1));
    }
  }
  return total;
}

void main() {
  test('one camera profile costs no backoff at all', () {
    expect(backoffFor(1), Duration.zero);
  });

  test('the three-profile ladder has a short bounded backoff', () {
    expect(backoffFor(3), const Duration(milliseconds: 750));
  });

  test('the retry budget remains below one second', () {
    expect(backoffFor(3), lessThan(const Duration(seconds: 1)));
  });
}
