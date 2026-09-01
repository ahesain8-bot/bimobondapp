import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';

import '../../../domain/usecases/dispose_camera.dart';
import '../../../domain/usecases/initialize_camera.dart';
import '../../utils/ar_live_beauty_defaults.dart';
import '../../widgets/start_live/ar_live_camera_preview.dart';
import 'live_event.dart';
import 'live_state.dart';

/// Orchestrates the live start screen business logic:
/// camera lifecycle, tools visibility, source and tab selection.
class LiveBloc extends Bloc<LiveEvent, LiveState> {
  LiveBloc({
    required InitializeCamera initializeCamera,
    required DisposeCamera disposeCamera,
    this.reuseHostArCamera = false,
  })  : _initializeCamera = initializeCamera,
        _disposeCamera = disposeCamera,
        super(const LiveInitial()) {
    on<LiveInitializeRequested>(_onInitialize);
    on<LiveCameraSwitchRequested>(_onSwitchCamera);
    on<LiveToolsToggleRequested>(_onToggleTools);
    on<LiveSourceChanged>(_onSourceChanged);
    on<LiveTabChanged>(_onTabChanged);
    on<LiveAppPaused>(_onAppPaused);
    on<LiveAppResumed>(_onAppResumed);
    on<LiveCameraHandedOff>(_onCameraHandedOff);
  }

  final InitializeCamera _initializeCamera;
  final DisposeCamera _disposeCamera;

  /// Host post-camera keeps the Kotlin PlatformView; we only drive beauty/UI.
  final bool reuseHostArCamera;

  bool get _useArBeauty =>
      ArLiveCameraPreview.isSupported && !reuseHostArCamera;

  /// Wait for AndroidView / PlatformView to attach after stopCamera handoff.
  static const _arAttachDelay = Duration(milliseconds: 450);

  LiveReady _ready(LiveState state) {
    return state is LiveReady ? state : const LiveReady();
  }

  /// PlatformView.init already starts CameraX; we re-bind + apply beauty once
  /// the view is up. Retry because startCamera is a no-op if refs are null.
  Future<void> _bootArBeauty({required bool isFront}) async {
    await Future<void>.delayed(_arAttachDelay);
    for (var i = 0; i < 6; i++) {
      if (isClosed) return;
      await ArCameraBridge.startCamera();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (isClosed) return;
    await ArLiveBeautyDefaults.applyWithRetry(isFrontCamera: isFront);
  }

  Future<void> _onInitialize(
    LiveInitializeRequested event,
    Emitter<LiveState> emit,
  ) async {
    emit(const LiveCameraInitializing());

    if (reuseHostArCamera) {
      // Camera already running on the route underneath.
      emit(
        const LiveReady(
          controller: null,
          isCameraInitialized: true,
          isFrontCamera: true,
        ),
      );
      ArLiveBeautyDefaults.apply(isFrontCamera: true);
      return;
    }

    if (_useArBeauty) {
      // Mount PlatformView FIRST — starting before attach is a no-op / black.
      emit(
        const LiveReady(
          controller: null,
          isCameraInitialized: true,
          isFrontCamera: true,
        ),
      );
      await _bootArBeauty(isFront: true);
      return;
    }

    final controller = await _initializeCamera(useFront: true);
    if (isClosed) return;
    emit(
      LiveReady(
        controller: controller,
        isCameraInitialized: controller != null,
        isFrontCamera: true,
      ),
    );
  }

  Future<void> _onSwitchCamera(
    LiveCameraSwitchRequested event,
    Emitter<LiveState> emit,
  ) async {
    final current = _ready(state);
    if (!current.isCameraInitialized) return;

    if (_useArBeauty || reuseHostArCamera) {
      final nextIsFront = !current.isFrontCamera;
      emit(current.copyWith(isFrontCamera: nextIsFront));
      await ArCameraBridge.flipCamera();
      ArLiveBeautyDefaults.apply(isFrontCamera: nextIsFront);
      return;
    }

    final oldController = current.controller;
    if (oldController == null) return;

    await _disposeCamera(oldController);
    final nextIsFront = !current.isFrontCamera;
    emit(
      current.copyWith(
        controller: null,
        isCameraInitialized: false,
        isFrontCamera: nextIsFront,
      ),
    );

    final controller = await _initializeCamera(useFront: nextIsFront);
    if (isClosed) return;
    if (controller != null) {
      emit(
        current.copyWith(
          controller: controller,
          isCameraInitialized: true,
          isFrontCamera: nextIsFront,
        ),
      );
    } else {
      final fallback = await _initializeCamera(useFront: !nextIsFront);
      if (isClosed) return;
      emit(
        current.copyWith(
          controller: fallback,
          isCameraInitialized: fallback != null,
          isFrontCamera: !nextIsFront,
        ),
      );
    }
  }

  void _onToggleTools(LiveToolsToggleRequested event, Emitter<LiveState> emit) {
    final current = _ready(state);
    emit(current.copyWith(isToolsExpanded: !current.isToolsExpanded));
  }

  void _onSourceChanged(LiveSourceChanged event, Emitter<LiveState> emit) {
    final current = _ready(state);
    emit(current.copyWith(isDeviceCamera: event.isDeviceCamera));
  }

  void _onTabChanged(LiveTabChanged event, Emitter<LiveState> emit) {
    final current = _ready(state);
    emit(current.copyWith(selectedIndex: event.index));
  }

  Future<void> _onAppPaused(
    LiveAppPaused event,
    Emitter<LiveState> emit,
  ) async {
    final current = _ready(state);
    if (!current.isCameraInitialized) return;

    // AR / host FaceWarp must keep CameraX for LiveKit beauty publish.
    if (_useArBeauty || reuseHostArCamera) {
      return;
    }

    final controller = current.controller;
    if (controller == null) return;
    await _disposeCamera(controller);
    if (isClosed) return;
    emit(current.copyWith(controller: null, isCameraInitialized: false));
  }

  Future<void> _onAppResumed(
    LiveAppResumed event,
    Emitter<LiveState> emit,
  ) async {
    final current = _ready(state);

    if (reuseHostArCamera) {
      // Host post-camera owns CameraX restart after the live route pops.
      return;
    }

    if (_useArBeauty) {
      if (!current.isCameraInitialized) {
        emit(current.copyWith(isCameraInitialized: true));
      }
      await _bootArBeauty(isFront: current.isFrontCamera);
      return;
    }

    if (current.controller != null && current.isCameraInitialized) return;
    final controller = await _initializeCamera(useFront: current.isFrontCamera);
    if (isClosed) return;
    emit(
      current.copyWith(
        controller: controller,
        isCameraInitialized: controller != null,
      ),
    );
  }

  /// Room takes over — for Flutter camera, hand off the controller. For AR,
  /// keep CameraX / FaceWarp running so beauty frames can be published.
  Future<void> _onCameraHandedOff(
    LiveCameraHandedOff event,
    Emitter<LiveState> emit,
  ) async {
    final current = _ready(state);
    if (!current.isCameraInitialized && current.controller == null) return;

    if (_useArBeauty || reuseHostArCamera) {
      // Do NOT stopCamera — LiveKit beauty capturer reads FaceWarp frames.
      return;
    }

    // Flutter path: forget controller WITHOUT disposing — room owns it.
    if (isClosed) return;
    emit(current.copyWith(controller: null, isCameraInitialized: false));
  }
}
