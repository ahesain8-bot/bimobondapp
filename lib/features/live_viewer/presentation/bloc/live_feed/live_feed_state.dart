import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
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
    return LiveFeedLoadSuccess(
      lives: lives ?? this.lives,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
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
