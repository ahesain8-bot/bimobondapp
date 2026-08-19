import 'package:flutter/material.dart';

class DeviceLifecycleManager with WidgetsBindingObserver {
  VoidCallback? onAppPaused;
  VoidCallback? onAppResumed;
  bool _isObserverRegistered = false;

  void startObserving({
    required VoidCallback onPaused,
    required VoidCallback onResumed,
  }) {
    onAppPaused = onPaused;
    onAppResumed = onResumed;

    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
      debugPrint('DeviceLifecycleManager: Started observing AppLifecycleState');
    }
  }

  void stopObserving() {
    if (_isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
      debugPrint('DeviceLifecycleManager: Stopped observing AppLifecycleState');
    }
    onAppPaused = null;
    onAppResumed = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('DeviceLifecycleManager: AppLifecycleState changed to $state');
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        onAppPaused?.call();
        break;
      case AppLifecycleState.resumed:
        onAppResumed?.call();
        break;
      case AppLifecycleState.detached:
        onAppPaused?.call();
        break;
    }
  }
}
