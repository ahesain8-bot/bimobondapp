import 'dart:async';

import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:flutter/material.dart';

/// Coordinates pausing the home feed when another screen covers it.
class FeedPlaybackGate extends ChangeNotifier {
  FeedPlaybackGate._();

  static final FeedPlaybackGate instance = FeedPlaybackGate._();

  bool _blocked = false;
  int _modalOverlayCount = 0;

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

  /// Call when a modal overlay (e.g. bottom sheet) opens above the feed.
  void pushModalOverlay() {
    _modalOverlayCount++;
    syncFromRouter();
  }

  /// Call when a modal overlay closes.
  void popModalOverlay() {
    if (_modalOverlayCount > 0) {
      _modalOverlayCount--;
    }
    syncFromRouter();
  }

  @Deprecated('Use syncFromRouter')
  void syncFromNavigator() => syncFromRouter();

  void syncFromRouter() {
    setBlocked(_shouldBlockFeed());
  }

  bool _shouldBlockFeed() {
    if (_modalOverlayCount > 0) return true;

    final router = AppRouter.router;
    final matches = router.routerDelegate.currentConfiguration.matches;
    if (matches.length > 1) return true;

    if (matches.isNotEmpty) {
      final topLocation = matches.last.matchedLocation;
      if (topLocation != '/' && topLocation != '/splash') {
        return true;
      }
    }

    final navigator = AppRouter.rootNavigatorKey.currentState;
    return navigator?.canPop() ?? false;
  }
}

/// Keeps the feed paused for the lifetime of create-post flows.
mixin FeedPlaybackBlocker<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    FeedPlaybackGate.instance.setBlocked(true);
  }

  @override
  void dispose() {
    FeedPlaybackGate.instance.syncFromRouter();
    super.dispose();
  }
}

class FeedPlaybackNavigatorObserver extends NavigatorObserver {
  static final FeedPlaybackNavigatorObserver instance =
      FeedPlaybackNavigatorObserver();

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeedPlaybackGate.instance.syncFromRouter();
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
