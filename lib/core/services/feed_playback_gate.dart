import 'dart:async';

import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Coordinates pausing the home feed when another screen covers it.
class FeedPlaybackGate extends ChangeNotifier {
  FeedPlaybackGate._();

  static final FeedPlaybackGate instance = FeedPlaybackGate._();

  bool _blocked = false;

  bool get allowed => !_blocked;

  void setBlocked(bool blocked) {
    if (_blocked == blocked) return;
    _blocked = blocked;
    if (blocked) {
      unawaited(SoundAudioPreview.stop());
      notifyListeners();
      return;
    }
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_blocked) notifyListeners();
    });
  }

  void syncFromNavigator() {
    final navigator = AppRouter.rootNavigatorKey.currentState;
    setBlocked(navigator?.canPop() ?? false);
  }
}

/// Keeps the feed paused for the lifetime of create-post flows.
mixin FeedPlaybackBlocker<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    FeedPlaybackGate.instance.setBlocked(true);
  }
}

class FeedPlaybackNavigatorObserver extends NavigatorObserver {
  static final FeedPlaybackNavigatorObserver instance =
      FeedPlaybackNavigatorObserver();

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeedPlaybackGate.instance.syncFromNavigator();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sync();
  }
}
