import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../domain/usecases/get_live_feed_usecase.dart';
import 'live_feed_event.dart';
import 'live_feed_state.dart';

class LiveFeedBloc extends Bloc<LiveFeedEvent, LiveFeedState> {
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
  bool _followingOnly = false;
  int _queryGeneration = 0;
  static const _pageSize = 10;

  /// Prevents stacked silent polls while a previous one is still in flight.
  var _silentBusy = false;
  DateTime? _lastSilentAt;
  DateTime? _silentCooldownUntil;
  static const _silentMinInterval = Duration(seconds: 40);

  Future<void> _onLoadRequested(
    LiveFeedLoadRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    final queryChanged =
        _currentCategory != event.category ||
        _followingOnly != event.followingOnly;
    if (state.isLoading && !queryChanged) return;
    final generation = ++_queryGeneration;
    _currentCategory = event.category;
    _followingOnly = event.followingOnly;
    emit(
      LiveFeedLoadInProgress(
        lives: (event.refresh || queryChanged) ? const [] : state.lives,
        isLoading: true,
        hasMore: (event.refresh || queryChanged) ? true : state.hasMore,
        currentPage: (event.refresh || queryChanged) ? 1 : state.currentPage,
        error: (event.refresh || queryChanged) ? null : state.error,
      ),
    );

    final result = await getLiveFeedUseCase(
      page: (event.refresh || queryChanged) ? 1 : state.currentPage,
      limit: _pageSize,
      category: event.category,
      followingOnly: _followingOnly,
      // Opening Lives uses cache; only pull-to-refresh clears the TTL.
      forceRefresh: false,
    );

    if (generation != _queryGeneration || isClosed) return;
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
      (page) async {
        final merged = (event.refresh || queryChanged)
            ? page.lives
            : _dedupeAppend(state.lives, page.lives);
        emit(
          LiveFeedLoadSuccess(
            lives: merged,
            isLoading: false,
            hasMore: page.hasMore,
            currentPage: page.page + 1,
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
    final generation = _queryGeneration;
    emit(state.copyWith(isLoadingMore: true));
    final result = await getLiveFeedUseCase(
      page: state.currentPage,
      limit: _pageSize,
      category: _currentCategory,
      followingOnly: _followingOnly,
    );
    if (generation != _queryGeneration || isClosed) return;
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(isLoadingMore: false, hasMore: false, error: failure),
        );
      },
      (page) async {
        emit(
          state.copyWith(
            lives: _dedupeAppend(state.lives, page.lives),
            isLoadingMore: false,
            hasMore: page.hasMore,
            currentPage: page.page + 1,
            clearError: true,
          ),
        );
      },
    );
  }

  Future<void> _onRefreshRequested(
    LiveFeedRefreshRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    if (state.isLoading) return;
    final generation = ++_queryGeneration;
    emit(
      LiveFeedLoadInProgress(
        lives: const [],
        isLoading: true,
        hasMore: true,
        currentPage: 1,
        error: null,
      ),
    );
    final result = await getLiveFeedUseCase(
      page: 1,
      limit: _pageSize,
      category: _currentCategory,
      followingOnly: _followingOnly,
      forceRefresh: true,
    );
    if (generation != _queryGeneration || isClosed) return;
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
      (page) async {
        emit(
          LiveFeedLoadSuccess(
            lives: page.lives,
            isLoading: false,
            hasMore: page.hasMore,
            currentPage: page.page + 1,
            error: null,
          ),
        );
      },
    );
  }

  Future<void> _onSilentRefreshRequested(
    LiveFeedSilentRefreshRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore || _silentBusy) return;
    final cooldownUntil = _silentCooldownUntil;
    if (cooldownUntil != null && DateTime.now().isBefore(cooldownUntil)) {
      return;
    }
    final last = _lastSilentAt;
    if (last != null && DateTime.now().difference(last) < _silentMinInterval) {
      return;
    }
    final generation = _queryGeneration;
    _silentBusy = true;
    _lastSilentAt = DateTime.now();
    try {
      final result = await getLiveFeedUseCase(
        page: 1,
        limit: _pageSize,
        category: _currentCategory,
        followingOnly: _followingOnly,
        forceRefresh: false,
      );
      if (generation != _queryGeneration || isClosed) return;
      await result.fold(
        (failure) async {
          final msg = failure.message.toLowerCase();
          if (msg.contains('too many') || failure.code == '429') {
            _silentCooldownUntil = DateTime.now().add(
              const Duration(minutes: 2),
            );
          }
        },
        (page) async {
          final merged = _mergeSilent(state.lives, page.lives);
          if (merged.length == state.lives.length &&
              _sameIds(merged, state.lives)) {
            return;
          }
          emit(
            state.copyWith(
              lives: merged,
              hasMore: page.hasMore || state.hasMore,
            ),
          );
        },
      );
    } finally {
      _silentBusy = false;
    }
  }

  Future<void> _onLiveRemoved(
    LiveFeedLiveRemoved event,
    Emitter<LiveFeedState> emit,
  ) async {
    emit(
      state.copyWith(
        lives: state.lives.where((l) => l.id != event.liveId).toList(),
      ),
    );
  }

  /// Keep current order; refresh page-1 entries and append brand-new lives.
  static List<LiveEntity> _mergeSilent(
    List<LiveEntity> existing,
    List<LiveEntity> incoming,
  ) {
    if (incoming.isEmpty) return existing;
    final byId = {for (final live in incoming) live.feedEntryKey: live};
    final updated = existing
        .map((live) => byId.remove(live.feedEntryKey) ?? live)
        .toList();
    if (byId.isEmpty) return updated;
    return [...updated, ...byId.values];
  }

  /// Append [incoming] without duplicating live IDs already in [existing].
  static List<LiveEntity> _dedupeAppend(
    List<LiveEntity> existing,
    List<LiveEntity> incoming,
  ) {
    if (incoming.isEmpty) return existing;
    final seen = existing.map((l) => l.feedEntryKey).toSet();
    final additions = <LiveEntity>[];
    for (final live in incoming) {
      if (seen.add(live.feedEntryKey)) additions.add(live);
    }
    if (additions.isEmpty) return existing;
    return [...existing, ...additions];
  }

  static bool _sameIds(List<LiveEntity> a, List<LiveEntity> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
