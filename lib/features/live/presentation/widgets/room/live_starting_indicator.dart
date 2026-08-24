import 'dart:async';

import 'package:flutter/material.dart';

/// Non-blocking feedback for the host during the first publish handshake.
/// It is capped at seven seconds and disappears sooner when LiveKit publishes,
/// so the camera preview never looks frozen or broken while setup is running.
class LiveStartingIndicator extends StatefulWidget {
  const LiveStartingIndicator({
    required this.deadline,
    required this.isPublished,
    super.key = const ValueKey('live-starting-indicator'),
  });

  final DateTime deadline;
  final bool isPublished;

  @override
  State<LiveStartingIndicator> createState() => _LiveStartingIndicatorState();
}

class _LiveStartingIndicatorState extends State<LiveStartingIndicator> {
  Timer? _timer;
  var _withinStartWindow = true;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant LiveStartingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _scheduleHide();
  }

  void _scheduleHide() {
    _timer?.cancel();
    final remaining = widget.deadline.difference(DateTime.now());
    _withinStartWindow = !remaining.isNegative;
    if (!_withinStartWindow) return;
    _timer = Timer(remaining, () {
      if (mounted) setState(() => _withinStartWindow = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_withinStartWindow || widget.isPublished) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB3000000),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'جاري تجهيز البث…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
