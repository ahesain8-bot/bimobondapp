import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../domain/usecases/get_live_feed_usecase.dart';
import 'live_feed_event.dart';
import 'live_feed_state.dart';

class LiveFeedBloc extends Bloc<LiveFeedEvent, LiveFeedState> {
  static const _pageSize = 20;

  LiveFeedBloc({required this.getLiveFeedUseCase})
    : super(const LiveFeedInitial()) {
    on<LiveFeedLoadRequested>(_onLoadRequested);
    on<LiveFeedLoadMoreRequested>(_onLoadMoreRequested);
    on<LiveFeedRefreshRequested>(_onRefreshRequested);
    on<LiveFeedSilentRefreshRequested>(_onSilentRefreshRequested);
    on<LiveFeedLiveRemoved>(_onLiveRemoved);
  }

  final GetLiveFeedUseCase getLiveFeedUseCase;
  String? _currentCategory;
  bool _currentFollowingOnly = false;

  /// Ids the server last returned for page 1.
  ///
  /// Reconciliation needs to distinguish "this live ended" from "this live is
  /// on page 2, which the refresh did not ask for". Only ids we have actually
  /// seen inside the page-1 window are candidates for removal, which is what
  /// makes it impossible for a page-1 refresh to delete paged-in content.
  var _page1Ids = <String>{};

  Future<void> _onLoadRequested(
    LiveFeedLoadRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    if (state.isLoading) return;
    _currentCategory = event.category;
    _currentFollowingOnly = event.followingOnly;
    emit(
      LiveFeedLoadInProgress(
        lives: state.lives,
        isLoading: true,
        hasMore: state.hasMore,
        currentPage: event.refresh ? 1 : state.currentPage,
        error: event.refresh ? null : state.error,
      ),
    );

    final result = await getLiveFeedUseCase(
      page: event.refresh ? 1 : state.currentPage,
      limit: _pageSize,
      category: event.category,
      followingOnly: event.followingOnly,
    );

    await result.fold(
      (failure) async {
        emit(
          LiveFeedLoadFailure(
            failure: failure,
            lives: state.lives,
            hasMore: state.hasMore,
            currentPage: state.currentPage,
          ),
        );
      },
      (lives) async {
        final allLives = event.refresh ? lives : [...state.lives, ...lives];
        if (event.refresh || state.currentPage <= 1) {
          _page1Ids = lives.map((live) => live.id).toSet();
        }
        emit(
          LiveFeedLoadSuccess(
            lives: allLives,
            isLoading: false,
            hasMore: lives.length >= _pageSize,
            currentPage: event.refresh ? 2 : state.currentPage + 1,
            error: null,
          ),
        );
      },
    );
  }

  Future<void> _onLoadMoreRequested(
    LiveFeedLoadMoreRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    emit(state.copyWith(isLoadingMore: true));
    final result = await getLiveFeedUseCase(
      page: state.currentPage,
      limit: _pageSize,
      category: event.category ?? _currentCategory,
      followingOnly: event.followingOnly ?? _currentFollowingOnly,
    );
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(isLoadingMore: false, hasMore: false, error: failure),
        );
      },
      (lives) async {
        emit(
          state.copyWith(
            lives: [...state.lives, ...lives],
            isLoadingMore: false,
            hasMore: lives.length >= _pageSize,
            currentPage: state.currentPage + 1,
          ),
        );
      },
    );
  }

  Future<void> _onRefreshRequested(
    LiveFeedRefreshRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    add(
      LiveFeedLoadRequested(
        category: _currentCategory,
        followingOnly: _currentFollowingOnly,
        refresh: true,
      ),
    );
  }

  /// Reconciles the page-1 window against the server every few seconds.
  ///
  /// The refresh only ever asked for page 1, so it is only evidence about page
  /// 1. The list is rebuilt as `[fresh page 1] + [page-1 items we cannot prove
  /// ended] + [everything paged in beyond page 1]`, which gives new lives the
  /// position the server chose for them instead of appending them to the end,
  /// and leaves paged-in content untouched.
  ///
  /// Removal is deliberately conservative. A live missing from a *full* page 1
  /// may simply have been pushed onto page 2 by newer lives, so it is kept;
  /// only a short page — where the whole feed provably fits in one page — lets
  /// absence mean "ended". Lives that end while the viewer is elsewhere in the
  /// list are removed by [LiveFeedLiveRemoved] from the Socket.IO signal
  /// instead, which is authoritative and immediate.
  Future<void> _onSilentRefreshRequested(
    LiveFeedSilentRefreshRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore) return;
    final result = await getLiveFeedUseCase(
      page: 1,
      limit: _pageSize,
      category: _currentCategory,
      followingOnly: _currentFollowingOnly,
    );
    await result.fold((_) async {}, (fresh) async {
      final freshIds = fresh.map((live) => live.id).toSet();
      final pageOneIsComplete = fresh.length < _pageSize;

      final carried = <LiveEntity>[];
      final tail = <LiveEntity>[];
      for (final live in state.lives) {
        if (freshIds.contains(live.id)) continue;
        if (_page1Ids.contains(live.id)) {
          if (!pageOneIsComplete) carried.add(live);
          continue;
        }
        tail.add(live);
      }

      final reconciled = <LiveEntity>[...fresh, ...carried, ...tail];
      _page1Ids = freshIds;
      if (_sameOrder(state.lives, reconciled)) return;
      emit(state.copyWith(lives: reconciled));
    });
  }

  static bool _sameOrder(List<LiveEntity> a, List<LiveEntity> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _onLiveRemoved(
    LiveFeedLiveRemoved event,
    Emitter<LiveFeedState> emit,
  ) async {
    _page1Ids.remove(event.liveId);
    final remaining = state.lives
        .where((l) => l.id != event.liveId)
        .toList(growable: false);
    if (remaining.length == state.lives.length) return;
    emit(state.copyWith(lives: remaining));
  }
}
