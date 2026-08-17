import 'package:flutter_bloc/flutter_bloc.dart';

import 'live_event.dart';
import 'live_state.dart';

/// Orchestrates the live start screen UI state:
/// tools visibility, source and tab selection.
///
/// UI-only version: no camera lifecycle.
class LiveBloc extends Bloc<LiveEvent, LiveState> {
  LiveBloc() : super(const LiveInitial()) {
    on<LiveInitializeRequested>(_onInitialize);
    on<LiveToolsToggleRequested>(_onToggleTools);
    on<LiveSourceChanged>(_onSourceChanged);
    on<LiveTabChanged>(_onTabChanged);
  }

  LiveReady _ready(LiveState state) {
    return state is LiveReady ? state : const LiveReady();
  }

  void _onInitialize(
    LiveInitializeRequested event,
    Emitter<LiveState> emit,
  ) {
    emit(const LiveReady());
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
}
