import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';

import '../../../domain/entities/hourly_ranking_entity.dart';
import '../../../domain/usecases/get_hourly_leaderboard_usecase.dart';
import '../../../domain/usecases/get_live_hourly_rank_usecase.dart';
import '../../../domain/usecases/watch_live_hourly_rank_usecase.dart';
import 'hourly_ranking_event.dart';
import 'hourly_ranking_state.dart';

/// Drives the hourly ranking sheet from `GET /lives/leaderboard/hourly`,
/// `GET /lives/:id/leaderboard/hourly` and socket `liveHourlyRankUpdated`.
class HourlyRankingBloc extends Bloc<HourlyRankingEvent, HourlyRankingState> {
  HourlyRankingBloc({
    required this.getHourlyLeaderboardUseCase,
    required this.getLiveHourlyRankUseCase,
    required this.watchLiveHourlyRankUseCase,
  }) : super(const HourlyRankingInitial()) {
    on<HourlyRankingRequested>(_onRequested);
    on<HourlyRankingRefreshRequested>(_onRefreshRequested);
    on<HourlyRankingSilentRefreshRequested>(_onSilentRefreshRequested);
    on<HourlyRankingTabChanged>(_onTabChanged);
    on<HourlyRankingLiveRankUpdated>(_onLiveRankUpdated);
  }

  final GetHourlyLeaderboardUseCase getHourlyLeaderboardUseCase;
  final GetLiveHourlyRankUseCase getLiveHourlyRankUseCase;
  final WatchLiveHourlyRankUseCase watchLiveHourlyRankUseCase;

  /// A rank change means the whole board moved, but the socket only carries the
  /// one stream. Re-reading the board on every gift would hammer an endpoint
  /// the backend itself flags as expensive, so list reloads are throttled.
  static const _silentReloadInterval = Duration(seconds: 10);

  StreamSubscription<LiveHourlyRank>? _rankSub;
  String? _liveId;
  int _limit = 20;

  /// Last time the board was *requested*, not last success — otherwise a
  /// failing endpoint would be retried on every socket tick.
  DateTime? _lastBoardFetchAt;

  Future<void> _onRequested(
    HourlyRankingRequested event,
    Emitter<HourlyRankingState> emit,
  ) async {
    if (state.isLoading) return;
    _liveId = event.liveId;
    _limit = event.limit;
    _listenLiveRank(event.liveId);

    emit(
      HourlyRankingLoadInProgress(
        leaderboard: state.leaderboard,
        liveRank: state.liveRank,
        tab: state.tab,
      ),
    );
    await _load(emit);
  }

  Future<void> _onRefreshRequested(
    HourlyRankingRefreshRequested event,
    Emitter<HourlyRankingState> emit,
  ) async {
    if (state.isLoading) return;
    emit(
      HourlyRankingLoadInProgress(
        leaderboard: state.leaderboard,
        liveRank: state.liveRank,
        tab: state.tab,
      ),
    );
    await _load(emit);
  }

  Future<void> _onSilentRefreshRequested(
    HourlyRankingSilentRefreshRequested event,
    Emitter<HourlyRankingState> emit,
  ) async {
    if (state.isLoading) return;
    _lastBoardFetchAt = DateTime.now();
    final result = await getHourlyLeaderboardUseCase(limit: _limit);
    // A silent reload keeps whatever is on screen when it fails — the visible
    // ranking is still the last thing the backend actually said.
    result.fold((_) {}, (leaderboard) {
      emit(
        HourlyRankingLoadSuccess(
          leaderboard: leaderboard,
          liveRank: state.liveRank,
          tab: state.tab,
        ),
      );
    });
  }

  void _onTabChanged(
    HourlyRankingTabChanged event,
    Emitter<HourlyRankingState> emit,
  ) {
    if (event.tab == state.tab) return;
    final error = state.error;
    if (error != null) {
      emit(
        HourlyRankingLoadFailure(
          failure: error,
          leaderboard: state.leaderboard,
          liveRank: state.liveRank,
          tab: event.tab,
        ),
      );
      return;
    }
    emit(
      HourlyRankingLoadSuccess(
        leaderboard: state.leaderboard,
        liveRank: state.liveRank,
        tab: event.tab,
      ),
    );
  }

  void _onLiveRankUpdated(
    HourlyRankingLiveRankUpdated event,
    Emitter<HourlyRankingState> emit,
  ) {
    final error = state.error;
    if (error != null) {
      emit(
        HourlyRankingLoadFailure(
          failure: error,
          leaderboard: state.leaderboard,
          liveRank: event.rank,
          tab: state.tab,
        ),
      );
    } else {
      emit(
        HourlyRankingLoadSuccess(
          leaderboard: state.leaderboard,
          liveRank: event.rank,
          tab: state.tab,
        ),
      );
    }

    final last = _lastBoardFetchAt;
    if (last == null ||
        DateTime.now().difference(last) >= _silentReloadInterval) {
      add(const HourlyRankingSilentRefreshRequested());
    }
  }

  Future<void> _load(Emitter<HourlyRankingState> emit) async {
    final liveId = _liveId;
    _lastBoardFetchAt = DateTime.now();
    final boardFuture = getHourlyLeaderboardUseCase(limit: _limit);
    final rankFuture = (liveId != null && liveId.isNotEmpty)
        ? getLiveHourlyRankUseCase(liveId)
        : Future<Either<Failure, LiveHourlyRank>?>.value(null);

    final boardResult = await boardFuture;
    final rankResult = await rankFuture;

    // The stream's own rank is supplementary — losing it must not blank the
    // ranking list, so it degrades to "unranked" instead of an error screen.
    final liveRank =
        rankResult?.fold((_) => null, (rank) => rank) ?? state.liveRank;

    boardResult.fold(
      (failure) => emit(
        HourlyRankingLoadFailure(
          failure: failure,
          leaderboard: state.leaderboard,
          liveRank: liveRank,
          tab: state.tab,
        ),
      ),
      (leaderboard) => emit(
        HourlyRankingLoadSuccess(
          leaderboard: leaderboard,
          liveRank: liveRank,
          tab: state.tab,
        ),
      ),
    );
  }

  void _listenLiveRank(String? liveId) {
    _rankSub?.cancel();
    _rankSub = null;
    if (liveId == null || liveId.isEmpty) return;
    _rankSub = watchLiveHourlyRankUseCase(liveId).listen((rank) {
      if (!isClosed) add(HourlyRankingLiveRankUpdated(rank));
    });
  }

  @override
  Future<void> close() {
    _rankSub?.cancel();
    return super.close();
  }
}
