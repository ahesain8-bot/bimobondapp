import 'package:flutter/widgets.dart';

import 'live_face_tracker.dart';

/// Exposes [LiveFaceTracker] to the Live Room subtree.
class LiveFaceTrackerScope extends InheritedNotifier<LiveFaceTracker> {
  const LiveFaceTrackerScope({
    super.key,
    required LiveFaceTracker tracker,
    required super.child,
  }) : super(notifier: tracker);

  static LiveFaceTracker of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LiveFaceTrackerScope>();
    assert(scope != null, 'LiveFaceTrackerScope not found in context');
    return scope!.notifier!;
  }
}
