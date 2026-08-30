import 'dart:async';

import 'package:flutter/material.dart';

/// Full-screen pre-live countdown shown over the camera preview.
class LiveCountdownOverlay {
  const LiveCountdownOverlay._();

  /// Pushes the countdown route and completes when the countdown finishes
  /// (the overlay pops itself before the future resolves).
  static Future<void> run(BuildContext context) async {
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) =>
            LiveCountdownLayer(onFinished: () => navigator.pop()),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// Embedded countdown layer for the live room.
///
/// The room starts its server/LiveKit connection as soon as this widget is
/// mounted. This layer only hides that work behind 1 → 2 → 3, instead of
/// delaying the connection until the countdown has finished.
class LiveCountdownLayer extends StatefulWidget {
  const LiveCountdownLayer({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<LiveCountdownLayer> createState() => _LiveCountdownLayerState();
}

class _LiveCountdownLayerState extends State<LiveCountdownLayer> {
  Timer? _timer;
  int _value = 1;

  @override
  void initState() {
    super.initState();
    // Chained one-shot timers instead of a single periodic timer: a periodic
    // timer keeps re-firing while a frame is being skipped, which can stack up
    // callbacks. Each step schedules the next one explicitly.
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_value >= 3) {
        _finish();
        return;
      }
      setState(() => _value++);
      _scheduleNext();
    });
  }

  void _finish() {
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          // NO overshooting curves (easeOutBack/elastic) here: their transformed
          // values leave [0, 1] and CurvedAnimation throws "parametric value
          // outside of [0, 1] range", which in release builds aborts the frame
          // and freezes the whole app.
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: Tween<double>(begin: 1.6, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            '$_value',
            key: ValueKey<int>(_value),
            style: TextStyle(
              color: Colors.white,
              fontSize: 90,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
                Shadow(
                  color: const Color(0xFFFE2C55).withValues(alpha: 0.45),
                  blurRadius: 48,
                  offset: Offset.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
