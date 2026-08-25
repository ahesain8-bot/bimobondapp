import 'package:flutter/widgets.dart';

/// Returns whether the route that owns a realtime gift renderer is currently
/// visible. Covered routes must not retain a gift and replay it when another
/// live-room route is popped.
bool isRealtimeGiftRouteCurrent(BuildContext context) {
  return ModalRoute.of(context)?.isCurrent == true;
}
