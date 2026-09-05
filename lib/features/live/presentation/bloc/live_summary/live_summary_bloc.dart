import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_interactive.dart';
import '../../../domain/repositories/live_interactive_repository.dart';

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

/// Loads the read-only recap shown after a live ends.
class LiveSummaryBloc extends Bloc<LiveSummaryEvent, LiveSummaryState> {
  LiveSummaryBloc({required LiveInteractiveRepository repository})
    : _repository = repository,
      super(const LiveSummaryState()) {
    on<LiveSummaryRequested>(_onRequested);
  }

  final LiveInteractiveRepository _repository;

  Future<void> _onRequested(
    LiveSummaryRequested event,
    Emitter<LiveSummaryState> emit,
  ) async {
    emit(const LiveSummaryState(isLoading: true));
    try {
      final summary = await _repository.getSummary(event.liveId);
      if (!isClosed) emit(LiveSummaryState(summary: summary));
    } catch (e) {
      if (!isClosed) emit(LiveSummaryState(error: e.toString()));
    }
  }
}
