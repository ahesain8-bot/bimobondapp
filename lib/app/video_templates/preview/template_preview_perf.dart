import 'package:flutter/foundation.dart';

/// Debug-only timing for soft template preview (no-op in release).
abstract final class TemplatePreviewPerf {
  static void log(String phase, int ms, {String? detail}) {
    if (!kDebugMode) return;
    final extra = (detail == null || detail.isEmpty) ? '' : ' $detail';
    debugPrint('TemplatePreview: $phase=${ms}ms$extra');
  }

  static Stopwatch start() => Stopwatch()..start();

  static void end(Stopwatch sw, String phase, {String? detail}) {
    if (!sw.isRunning) return;
    sw.stop();
    log(phase, sw.elapsedMilliseconds, detail: detail);
  }
}
