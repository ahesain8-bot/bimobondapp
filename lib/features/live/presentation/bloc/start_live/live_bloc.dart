import 'package:bimobondapp/app/camera_engine/native_camera_controller.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/dispose_camera.dart';
import '../../../domain/usecases/initialize_camera.dart';
import 'live_event.dart';
import 'live_state.dart';

/// Orchestrates the live start screen business logic:
/// camera lifecycle, tools visibility, source and tab selection.
class LiveBloc extends Bloc<LiveEvent, LiveState> {
  LiveBloc({
    required InitializeCamera initializeCamera,
    required DisposeCamera disposeCamera,
  }) : _initializeCamera =
           initializeCamera, // ignore: prefer_initializing_formals
       _disposeCamera = disposeCamera, // ignore: prefer_initializing_formals
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

  bool get _preferNativeCamera =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _useExistingArCamera =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<NativeCameraController?> _openNativeCamera() async {
    if (!_preferNativeCamera) return null;
    final controller = NativeCameraController();
    try {
      await controller.start();
      return controller;
    } catch (_) {
      await controller.releaseNative();
      controller.dispose();
      return null;
    }
  }

  Future<void> _releaseNativeCamera(NativeCameraController controller) async {
    await controller.releaseNative();
    controller.dispose();
  }

  LiveReady _ready(LiveState state) {
    return state is LiveReady ? state : const LiveReady();
  }

  Future<void> _onInitialize(
    LiveInitializeRequested event,
    Emitter<LiveState> emit,
  ) async {
    emit(const LiveCameraInitializing());
    if (_useExistingArCamera) {
      try {
        await ArCameraBridge.warmup();
      } catch (_) {}
      if (!isClosed) {
        emit(const LiveReady(isCameraInitialized: true, isFrontCamera: true));
      }
      return;
    }
    final nativeController = await _openNativeCamera();
    if (isClosed) {
      if (nativeController != null) {
        await _releaseNativeCamera(nativeController);
      }
      return;
    }
    if (nativeController != null) {
      emit(
        LiveReady(
          nativeController: nativeController,
          isCameraInitialized: true,
          isFrontCamera: nativeController.state.isFront,
        ),
      );
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
    if (_useExistingArCamera && current.isCameraInitialized) {
      try {
        final isFront = await ArCameraBridge.flipCamera();
        if (!isClosed) emit(current.copyWith(isFrontCamera: isFront));
      } catch (_) {}
      return;
    }
    final nativeController = current.nativeController;
    if (nativeController != null && current.isCameraInitialized) {
      try {
        final next = await nativeController.switchCamera();
        if (isClosed) return;
        emit(
          current.copyWith(
            isFrontCamera: next.isFront,
            isCameraInitialized: next.ok,
          ),
        );
      } catch (_) {}
      return;
    }
    final oldController = current.controller;
    if (oldController == null || !current.isCameraInitialized) return;

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
      // The requested camera could not be opened: revert to the previous one.
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
    if (_useExistingArCamera) {
      await ArCameraBridge.suspendPreview();
      if (!isClosed) emit(current.copyWith(isCameraInitialized: false));
      return;
    }
    final nativeController = current.nativeController;
    if (nativeController != null && current.isCameraInitialized) {
      try {
        await nativeController.stop();
      } catch (_) {}
      if (isClosed) return;
      emit(current.copyWith(isCameraInitialized: false));
      return;
    }
    final controller = current.controller;
    if (controller == null || !current.isCameraInitialized) return;
    await _disposeCamera(controller);
    if (isClosed) return;
    emit(current.copyWith(controller: null, isCameraInitialized: false));
  }

  Future<void> _onAppResumed(
    LiveAppResumed event,
    Emitter<LiveState> emit,
  ) async {
    final current = _ready(state);
    if (_useExistingArCamera) {
      await ArCameraBridge.resumePreview();
      if (!isClosed) {
        emit(current.copyWith(isCameraInitialized: true));
      }
      return;
    }
    if ((current.controller != null || current.nativeController != null) &&
        current.isCameraInitialized) {
      return;
    }
    final existingNative = current.nativeController;
    if (existingNative != null) {
      try {
        final next = await existingNative.start();
        if (isClosed) return;
        emit(
          current.copyWith(
            isCameraInitialized: next.ok,
            isFrontCamera: next.isFront,
          ),
        );
        return;
      } catch (_) {
        await _releaseNativeCamera(existingNative);
      }
    }
    final nativeController = await _openNativeCamera();
    if (isClosed) {
      if (nativeController != null) {
        await _releaseNativeCamera(nativeController);
      }
      return;
    }
    if (nativeController != null) {
      emit(
        current.copyWith(
          controller: null,
          nativeController: nativeController,
          isCameraInitialized: true,
          isFrontCamera: nativeController.state.isFront,
        ),
      );
      return;
    }
    final controller = await _initializeCamera(useFront: current.isFrontCamera);
    if (isClosed) return;
    emit(
      current.copyWith(
        controller: controller,
        nativeController: null,
        isCameraInitialized: controller != null,
      ),
    );
  }

  /// The live room took ownership of the running camera.
  /// Forget it here WITHOUT disposing — the room disposes it on handoff.
  void _onCameraHandedOff(LiveCameraHandedOff event, Emitter<LiveState> emit) {
    final current = _ready(state);
    if (current.controller == null && !current.isCameraInitialized) return;
    emit(
      current.copyWith(
        controller: null,
        nativeController: null,
        isCameraInitialized: false,
      ),
    );
  }

  @override
  Future<void> close() async {
    final current = state is LiveReady ? state as LiveReady : null;
    final nativeController = current?.nativeController;
    if (nativeController != null) {
      await _releaseNativeCamera(nativeController);
    }
    final controller = current?.controller;
    if (controller != null) await _disposeCamera(controller);
    return super.close();
  }
}
