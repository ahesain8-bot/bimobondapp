import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
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

  Future<void> _onLoadRequested(
    LiveFeedLoadRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    if (state.isLoading) return;
    _currentCategory = event.category;
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
      limit: 10,
      category: event.category,
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
        emit(
          LiveFeedLoadSuccess(
            lives: allLives,
            isLoading: false,
            hasMore: lives.length >= 10,
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
      limit: 10,
      category: event.category ?? _currentCategory,
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
            hasMore: lives.length >= 10,
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
    add(LiveFeedLoadRequested(category: _currentCategory, refresh: true));
  }

  Future<void> _onSilentRefreshRequested(
    LiveFeedSilentRefreshRequested event,
    Emitter<LiveFeedState> emit,
  ) async {
    if (state.isLoading) return;
    final result = await getLiveFeedUseCase(
      page: 1,
      limit: 10,
      category: _currentCategory,
    );
    await result.fold((_) async {}, (lives) async {
      final existingIds = state.lives.map((l) => l.id).toSet();
      final newLives = lives.where((l) => !existingIds.contains(l.id));
      if (newLives.isEmpty) return;
      emit(state.copyWith(lives: [...state.lives, ...newLives]));
    });
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
}
