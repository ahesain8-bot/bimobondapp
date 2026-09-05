import 'package:flutter/foundation.dart';

/// Debug-only timing for live host/viewer startup (no-op in release).
///
/// Prefix: `LivePerf:` — use to measure REST → LiveKit → socket → ready
/// without spamming production logs.
abstract final class LiveRoomPerf {
  static void log(String phase, {int? ms, String? detail}) {
    if (!kDebugMode) return;
    final timing = ms == null ? '' : '=${ms}ms';
    final extra = (detail == null || detail.isEmpty) ? '' : ' $detail';
    debugPrint('LivePerf: $phase$timing$extra');
  }

  static Stopwatch start() => Stopwatch()..start();

  static void mark(Stopwatch sw, String phase, {String? detail}) {
    if (!kDebugMode) return;
    log(phase, ms: sw.elapsedMilliseconds, detail: detail);
  }

  static void end(Stopwatch sw, String phase, {String? detail}) {
    if (!sw.isRunning) return;
    sw.stop();
    mark(sw, phase, detail: detail);
  }
}
