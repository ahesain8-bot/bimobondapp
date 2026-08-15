import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/live_entity.dart';
import 'live_dependencies.dart';

export 'live_dependencies.dart' show liveRepositoryProvider;

class LiveFeedState {
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
    return LiveFeedState(
      lives: lives ?? this.lives,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class LiveFeedNotifier extends StateNotifier<LiveFeedState> {
  final Ref _ref;
  String? _currentCategory;

  LiveFeedNotifier(this._ref) : super(const LiveFeedState());

  Future<void> loadFeed({String? category, bool refresh = false}) async {
    if (state.isLoading) return;

    _currentCategory = category;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentPage: refresh ? 1 : state.currentPage,
      lives: refresh ? const [] : state.lives,
    );

    final result = await _ref.read(getLiveFeedUseCaseProvider)(
      page: refresh ? 1 : state.currentPage,
      limit: 10,
      category: category,
    );

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure);
      },
      (lives) {
        final allLives = refresh ? lives : [...state.lives, ...lives];
        state = state.copyWith(
          lives: allLives,
          isLoading: false,
          hasMore: lives.length >= 10,
          currentPage: refresh ? 2 : state.currentPage + 1,
          clearError: true,
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    final result = await _ref.read(getLiveFeedUseCaseProvider)(
      page: state.currentPage,
      limit: 10,
      category: _currentCategory,
    );

    result.fold(
      (failure) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
      },
      (lives) {
        state = state.copyWith(
          lives: [...state.lives, ...lives],
          isLoadingMore: false,
          hasMore: lives.length >= 10,
          currentPage: state.currentPage + 1,
        );
      },
    );
  }

  Future<void> refresh() async {
    await loadFeed(category: _currentCategory, refresh: true);
  }
}

final liveFeedProvider =
    StateNotifierProvider<LiveFeedNotifier, LiveFeedState>((ref) {
  return LiveFeedNotifier(ref);
});

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(liveRepositoryProvider);
  final result = await repository.getTrendingCategories();
  return result.getOrElse(() => []);
});
