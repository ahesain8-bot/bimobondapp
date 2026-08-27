import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/core/services/media_progress_watchdog.dart';

void main() {
  test('reports a frozen cumulative media counter once', () {
    final watchdog = MediaProgressWatchdog(stalledSampleLimit: 3);

    expect(watchdog.addSample(10), isFalse);
    expect(watchdog.addSample(10), isFalse);
    expect(watchdog.addSample(10), isFalse);
    expect(watchdog.addSample(10), isTrue);
    expect(watchdog.addSample(10), isFalse);
  });

  test('progress and track replacement reset the stalled run', () {
    final watchdog = MediaProgressWatchdog(stalledSampleLimit: 2);

    expect(watchdog.addSample(10), isFalse);
    expect(watchdog.addSample(10), isFalse);
    expect(watchdog.addSample(11), isFalse);
    expect(watchdog.addSample(11), isFalse);
    expect(watchdog.addSample(1), isFalse, reason: 'new track counter');
    expect(watchdog.addSample(1), isFalse);
    expect(watchdog.addSample(1), isTrue);
  });

  test('a deliberate pause is not a stall once sampling resumes', () {
    // What the host watchdog does when the camera is switched off: reset,
    // rather than counting the intentionally still counter towards a stall.
    final watchdog = MediaProgressWatchdog(stalledSampleLimit: 2);

    expect(watchdog.addSample(10), isFalse);
    expect(watchdog.addSample(10), isFalse);
    watchdog.reset();

    expect(watchdog.addSample(10), isFalse, reason: 'a fresh baseline');
    expect(watchdog.addSample(10), isFalse);
    expect(
      watchdog.addSample(10),
      isTrue,
      reason: 'a real freeze after the pause is still caught',
    );
  });

  test('reset clears a report so the watchdog can be reused', () {
    final watchdog = MediaProgressWatchdog(stalledSampleLimit: 1);

    expect(watchdog.addSample(5), isFalse);
    expect(watchdog.addSample(5), isTrue);
    expect(watchdog.addSample(5), isFalse, reason: 'latched after reporting');

    watchdog.reset();
    expect(watchdog.hasBaseline, isFalse);
    expect(watchdog.addSample(5), isFalse);
    expect(watchdog.addSample(5), isTrue);
  });

  test('unavailable stats do not create a false stall', () {
    final watchdog = MediaProgressWatchdog(stalledSampleLimit: 2);

    expect(watchdog.addSample(null), isFalse);
    expect(watchdog.addMissingTrackSample(), isFalse);
    expect(watchdog.addSample(4), isFalse);
    expect(watchdog.addSample(null), isFalse);
    expect(watchdog.addMissingTrackSample(), isFalse);
    expect(watchdog.addMissingTrackSample(), isTrue);
  });
}
