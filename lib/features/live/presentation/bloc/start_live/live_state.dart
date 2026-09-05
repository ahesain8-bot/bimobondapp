import 'package:camera/camera.dart';
import 'package:bimobondapp/app/camera_engine/native_camera_controller.dart';

const Object _unset = Object();

/// States emitted by [LiveBloc].
sealed class LiveState {
  const LiveState();
}

/// The bloc has not started yet.
class LiveInitial extends LiveState {
  const LiveInitial();
}

/// The camera is being initialized.
class LiveCameraInitializing extends LiveState {
  const LiveCameraInitializing();
}

/// The screen is ready; camera may or may not be available.
class LiveReady extends LiveState {
  const LiveReady({
    this.controller,
    this.nativeController,
    this.isCameraInitialized = false,
    this.isFrontCamera = true,
    this.isToolsExpanded = true,
    this.isDeviceCamera = true,
    this.selectedIndex = 2,
  });

  /// Active camera controller, `null` while not initialized.
  final CameraController? controller;

  /// Android CameraX/GPU preview. This is preferred over the Flutter camera
  /// and is handed to the live room until LiveKit takes ownership of the lens.
  final NativeCameraController? nativeController;

  /// Whether the camera is initialized and can be previewed.
  final bool isCameraInitialized;

  /// Whether the current camera is the front one.
  final bool isFrontCamera;

  /// Whether the second tools row is visible.
  final bool isToolsExpanded;

  /// Whether the source is the device camera (vs mobile games).
  final bool isDeviceCamera;

  /// Selected bottom tab index.
  final int selectedIndex;

  LiveReady copyWith({
    Object? controller = _unset,
    Object? nativeController = _unset,
    bool? isCameraInitialized,
    bool? isFrontCamera,
    bool? isToolsExpanded,
    bool? isDeviceCamera,
    int? selectedIndex,
  }) {
    return LiveReady(
      controller: identical(controller, _unset)
          ? this.controller
          : controller as CameraController?,
      nativeController: identical(nativeController, _unset)
          ? this.nativeController
          : nativeController as NativeCameraController?,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isToolsExpanded: isToolsExpanded ?? this.isToolsExpanded,
      isDeviceCamera: isDeviceCamera ?? this.isDeviceCamera,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LiveReady) return false;
    return other.controller == controller &&
        other.nativeController == nativeController &&
        other.isCameraInitialized == isCameraInitialized &&
        other.isFrontCamera == isFrontCamera &&
        other.isToolsExpanded == isToolsExpanded &&
        other.isDeviceCamera == isDeviceCamera &&
        other.selectedIndex == selectedIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      controller,
      nativeController,
      isCameraInitialized,
      isFrontCamera,
      isToolsExpanded,
      isDeviceCamera,
      selectedIndex,
    );
  }
}
