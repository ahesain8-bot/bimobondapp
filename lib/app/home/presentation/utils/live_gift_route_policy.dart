import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:flutter/widgets.dart';

/// Returns whether the route that owns a realtime gift renderer is currently
/// visible. Covered routes must not retain a gift and replay it when another
/// live-room route is popped.
///
/// A glass modal sheet is not such a hand-off: the gift sheet the sender just
/// used covers this route without another renderer taking ownership, and the
/// overlay is inserted above sheets anyway. Treating that as "covered" dropped
/// the sender's own gift, because the sheet is still up when the event lands.
bool isRealtimeGiftRouteCurrent(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null) return false;
  if (route.isCurrent) return true;
  return route.isActive && FeedPlaybackGate.instance.modalOverlayActive;
}
