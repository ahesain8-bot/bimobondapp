import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../live/domain/usecases/dispose_camera.dart';
import '../../../../live/domain/usecases/initialize_camera.dart';
import 'live_event.dart';
import 'live_state.dart';

/// Orchestrates the live start screen business logic:
/// camera lifecycle, tools visibility, source and tab selection.
class LiveBloc extends Bloc<LiveEvent, LiveState> {
  LiveBloc({
    required InitializeCamera initializeCamera,
    required DisposeCamera disposeCamera,
  })  : _initializeCamera = initializeCamera, // ignore: prefer_initializing_formals
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

  LiveReady _ready(LiveState state) {
    return state is LiveReady ? state : const LiveReady();
  }

  Future<void> _onInitialize(
    LiveInitializeRequested event,
    Emitter<LiveState> emit,
  ) async {
    emit(const LiveCameraInitializing());
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

  void _onToggleTools(
    LiveToolsToggleRequested event,
    Emitter<LiveState> emit,
  ) {
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

  /// The live room took ownership of the running camera.
  /// Forget it here WITHOUT disposing — the room disposes it on handoff.
  void _onCameraHandedOff(
    LiveCameraHandedOff event,
    Emitter<LiveState> emit,
  ) {
    final current = _ready(state);
    if (current.controller == null && !current.isCameraInitialized) return;
    emit(
      current.copyWith(
        controller: null,
        isCameraInitialized: false,
      ),
    );
  }
}
