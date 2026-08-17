/// States emitted by [LiveBloc].
sealed class LiveState {
  const LiveState();
}

/// The bloc has not started yet.
class LiveInitial extends LiveState {
  const LiveInitial();
}

/// The screen is ready (UI-only, no camera controller).
class LiveReady extends LiveState {
  const LiveReady({
    this.isToolsExpanded = true,
    this.isDeviceCamera = true,
    this.selectedIndex = 2,
  });

  /// Whether the second tools row is visible.
  final bool isToolsExpanded;

  /// Whether the source is the device camera (vs mobile games).
  final bool isDeviceCamera;

  /// Selected bottom tab index.
  final int selectedIndex;

  LiveReady copyWith({
    bool? isToolsExpanded,
    bool? isDeviceCamera,
    int? selectedIndex,
  }) {
    return LiveReady(
      isToolsExpanded: isToolsExpanded ?? this.isToolsExpanded,
      isDeviceCamera: isDeviceCamera ?? this.isDeviceCamera,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LiveReady) return false;
    return other.isToolsExpanded == isToolsExpanded &&
        other.isDeviceCamera == isDeviceCamera &&
        other.selectedIndex == selectedIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      isToolsExpanded,
      isDeviceCamera,
      selectedIndex,
    );
  }
}
