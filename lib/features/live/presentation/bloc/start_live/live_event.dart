/// Events handled by [LiveBloc].
sealed class LiveEvent {
  const LiveEvent();
}

/// Requests the initial camera initialization.
class LiveInitializeRequested extends LiveEvent {
  const LiveInitializeRequested();
}

/// Requests switching between the front and back camera.
class LiveCameraSwitchRequested extends LiveEvent {
  const LiveCameraSwitchRequested();
}

/// Toggles the visibility of the second tools row.
class LiveToolsToggleRequested extends LiveEvent {
  const LiveToolsToggleRequested();
}

/// Changes the broadcast source (device camera / mobile games).
class LiveSourceChanged extends LiveEvent {
  const LiveSourceChanged(this.isDeviceCamera);

  final bool isDeviceCamera;
}

/// Changes the selected bottom tab.
class LiveTabChanged extends LiveEvent {
  const LiveTabChanged(this.index);

  final int index;
}

/// The app went to the background; release camera resources.
class LiveAppPaused extends LiveEvent {
  const LiveAppPaused();
}

/// The app returned to the foreground; re-initialize the camera.
class LiveAppResumed extends LiveEvent {
  const LiveAppResumed();
}

/// The start-screen camera was handed to the live room (same lens, no reopen).
/// The controller is NOT disposed here — the room owns it now.
class LiveCameraHandedOff extends LiveEvent {
  const LiveCameraHandedOff();
}
