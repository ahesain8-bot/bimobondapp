import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_interactive.dart';
import '../../../domain/usecases/live_interactive_usecases.dart';

sealed class LiveSummaryEvent {
  const LiveSummaryEvent();
}

class LiveSummaryRequested extends LiveSummaryEvent {
  const LiveSummaryRequested(this.liveId);

  final String liveId;
}

class LiveSummaryState {
  const LiveSummaryState({this.isLoading = false, this.summary, this.error});

  final bool isLoading;
  final LiveSummary? summary;
  final String? error;
}

class LiveSummaryBloc extends Bloc<LiveSummaryEvent, LiveSummaryState> {
  LiveSummaryBloc({required LiveInteractiveUseCases useCases})
    : _useCases = useCases,
      super(const LiveSummaryState()) {
    on<LiveSummaryRequested>(_onRequested);
  }

  final LiveInteractiveUseCases _useCases;

  Future<void> _onRequested(
    LiveSummaryRequested event,
    Emitter<LiveSummaryState> emit,
  ) async {
    emit(const LiveSummaryState(isLoading: true));
    try {
      final summary = await _useCases.getSummary(event.liveId);
      if (!isClosed) emit(LiveSummaryState(summary: summary));
    } catch (error) {
      if (!isClosed) emit(LiveSummaryState(error: error.toString()));
    }
  }
}
