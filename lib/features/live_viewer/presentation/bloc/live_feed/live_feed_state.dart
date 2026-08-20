import 'package:equatable/equatable.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../../domain/entities/live_entity.dart';

abstract class LiveFeedState extends Equatable {
  final List<LiveEntity> lives;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Failure? error;
  final int currentPage;

  const LiveFeedState({
    this.lives = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 1,
  });

  LiveFeedState copyWith({
    List<LiveEntity>? lives,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Failure? error,
    int? currentPage,
    bool clearError = false,
  }) {
    final resolvedLives = lives ?? this.lives;
    final resolvedIsLoading = isLoading ?? this.isLoading;
    final resolvedIsLoadingMore = isLoadingMore ?? this.isLoadingMore;
    final resolvedHasMore = hasMore ?? this.hasMore;
    final resolvedError =
        clearError ? null : (error ?? this.error);
    final resolvedCurrentPage = currentPage ?? this.currentPage;

    final bool hadError = this.error != null;
    final bool keepAsFailure = hadError && resolvedError != null;
    final bool wantError = resolvedError != null;

    if (resolvedIsLoading) {
      return LiveFeedLoadInProgress(
        lives: resolvedLives,
        isLoading: true,
        isLoadingMore: resolvedIsLoadingMore,
        hasMore: resolvedHasMore,
        error: resolvedError,
        currentPage: resolvedCurrentPage,
      );
    }

    if (wantError) {
      return LiveFeedLoadFailure(
        failure: resolvedError!,
        lives: resolvedLives,
        isLoading: false,
        isLoadingMore: resolvedIsLoadingMore,
        hasMore: resolvedHasMore,
        currentPage: resolvedCurrentPage,
      );
    }

    // isLoading == false && error == null
    if (this is LiveFeedInitial && !keepAsFailure) {
      // Initial with no error + no loading stays Initial only if no real data
      // accumulated.  Once lives set (from any path) → become Success so that
      // UI branches on state is LiveFeedInitial correctly detect "first load
      // pending".
      if (resolvedLives.isEmpty) {
        return const LiveFeedInitial();
      }
    }

    return LiveFeedLoadSuccess(
      lives: resolvedLives,
      isLoading: false,
      isLoadingMore: resolvedIsLoadingMore,
      hasMore: resolvedHasMore,
      error: null,
      currentPage: resolvedCurrentPage,
    );
  }

  @override
  List<Object?> get props => [
    lives,
    isLoading,
    isLoadingMore,
    hasMore,
    error,
    currentPage,
  ];
}

class LiveFeedInitial extends LiveFeedState {
  const LiveFeedInitial() : super();
}

class LiveFeedLoadInProgress extends LiveFeedState {
  const LiveFeedLoadInProgress({
    super.lives = const [],
    super.isLoading = true,
    super.isLoadingMore = false,
    super.hasMore = true,
    super.error,
    super.currentPage = 1,
  });
}

class LiveFeedLoadSuccess extends LiveFeedState {
  const LiveFeedLoadSuccess({
    super.lives = const [],
    super.isLoading = false,
    super.isLoadingMore = false,
    super.hasMore = true,
    super.error,
    super.currentPage = 1,
  });
}

class LiveFeedLoadFailure extends LiveFeedState {
  const LiveFeedLoadFailure({
    required Failure failure,
    super.lives = const [],
    super.isLoading = false,
    super.isLoadingMore = false,
    super.hasMore = true,
    super.currentPage = 1,
  }) : super(error: failure);
}
