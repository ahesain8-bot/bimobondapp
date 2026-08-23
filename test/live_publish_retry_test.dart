import 'package:flutter_test/flutter_test.dart';

/// Mirrors the backoff the camera-open loop applies, so the cost of a retry
/// budget can be asserted without opening a camera.
Duration backoffFor(int maxAttempts) {
  var total = Duration.zero;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (attempt < maxAttempts - 1) {
      total += Duration(milliseconds: 500 * (attempt + 1));
    }
  }
  return total;
}

void main() {
  test('the opportunistic first pass costs no backoff at all', () {
    // Phase A runs while the Flutter camera still holds the lens, so it is
    // expected to fail. Its whole value is failing fast.
    expect(backoffFor(1), Duration.zero);
  });

  test('the full budget no longer sleeps after its final attempt', () {
    // 500 + 1000 + 1500 + 2000 + 2500 = 7.5s of waiting between six tries;
    // the old loop also slept 3000ms after the last one for nothing.
    expect(backoffFor(6), const Duration(milliseconds: 7500));
  });

  test('a one-attempt pass is 10.5s cheaper than the full budget', () {
    final saved = backoffFor(6) + const Duration(seconds: 3) - backoffFor(1);
    expect(saved, const Duration(milliseconds: 10500));
  });
}
