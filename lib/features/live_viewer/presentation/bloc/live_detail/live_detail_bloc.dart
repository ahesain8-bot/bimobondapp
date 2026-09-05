import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_entity.dart';
import '../../../domain/usecases/get_live_by_id_usecase.dart';

sealed class LiveDetailEvent {
  const LiveDetailEvent();
}

class LiveDetailRequested extends LiveDetailEvent {
  const LiveDetailRequested(this.liveId);

  final String liveId;
}

class LiveDetailState {
  const LiveDetailState({this.isLoading = false, this.live, this.error});

  final bool isLoading;
  final LiveEntity? live;
  final String? error;
}

class LiveDetailBloc extends Bloc<LiveDetailEvent, LiveDetailState> {
  LiveDetailBloc({required GetLiveByIdUseCase getLiveById})
    : _getLiveById = getLiveById,
      super(const LiveDetailState()) {
    on<LiveDetailRequested>(_onRequested);
  }

  final GetLiveByIdUseCase _getLiveById;

  Future<void> _onRequested(
    LiveDetailRequested event,
    Emitter<LiveDetailState> emit,
  ) async {
    emit(const LiveDetailState(isLoading: true));
    final result = await _getLiveById(event.liveId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(LiveDetailState(error: failure.message)),
      (live) => emit(LiveDetailState(live: live)),
    );
  }
}
