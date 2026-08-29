import 'package:equatable/equatable.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../../domain/entities/hourly_ranking_entity.dart';

/// The two tabs the ranking sheet renders. Both are served by
/// `GET /lives/leaderboard/hourly`; [trending] is the subset the backend
/// flagged `isPopular`.
enum HourlyRankingTab { trending, hourly }

abstract class HourlyRankingState extends Equatable {
  final HourlyLeaderboard leaderboard;

  /// This stream's standing, when the sheet was opened from inside a live.
  final LiveHourlyRank? liveRank;
  final HourlyRankingTab tab;
  final bool isLoading;
  final Failure? error;

  const HourlyRankingState({
    this.leaderboard = const HourlyLeaderboard(),
    this.liveRank,
    this.tab = HourlyRankingTab.trending,
    this.isLoading = false,
    this.error,
  });

  /// Rows for the selected tab.
  List<HourlyRankingEntry> get visibleEntries => switch (tab) {
    HourlyRankingTab.trending => leaderboard.trending,
    HourlyRankingTab.hourly => leaderboard.entries,
  };

  /// When the current ranking window closes, from the backend `windowEndsAt`.
  /// Null means the backend did not send a window and no countdown is shown.
  DateTime? get windowEndsAt => leaderboard.windowEndsAt;

  @override
  List<Object?> get props => [leaderboard, liveRank, tab, isLoading, error];
}

class HourlyRankingInitial extends HourlyRankingState {
  const HourlyRankingInitial() : super();
}

class HourlyRankingLoadInProgress extends HourlyRankingState {
  const HourlyRankingLoadInProgress({
    super.leaderboard = const HourlyLeaderboard(),
    super.liveRank,
    super.tab = HourlyRankingTab.trending,
    super.isLoading = true,
  });
}

class HourlyRankingLoadSuccess extends HourlyRankingState {
  const HourlyRankingLoadSuccess({
    required super.leaderboard,
    super.liveRank,
    super.tab = HourlyRankingTab.trending,
  }) : super(isLoading: false);
}

class HourlyRankingLoadFailure extends HourlyRankingState {
  const HourlyRankingLoadFailure({
    required Failure failure,
    super.leaderboard = const HourlyLeaderboard(),
    super.liveRank,
    super.tab = HourlyRankingTab.trending,
  }) : super(isLoading: false, error: failure);
}
