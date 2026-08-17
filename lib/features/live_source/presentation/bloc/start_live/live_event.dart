/// Events handled by [LiveBloc].
sealed class LiveEvent {
  const LiveEvent();
}

/// Requests the initial screen setup (UI-only, no camera).
class LiveInitializeRequested extends LiveEvent {
  const LiveInitializeRequested();
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
