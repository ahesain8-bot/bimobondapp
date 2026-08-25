import 'package:equatable/equatable.dart';

import '../../../domain/entities/hourly_ranking_entity.dart';
import 'hourly_ranking_state.dart';

abstract class HourlyRankingEvent extends Equatable {
  const HourlyRankingEvent();

  @override
  List<Object?> get props => const [];
}

/// First load for the sheet. [liveId] scopes the "this stream" header and the
/// realtime subscription; omit it to show the global ranking only.
class HourlyRankingRequested extends HourlyRankingEvent {
  final String? liveId;
  final int limit;

  const HourlyRankingRequested({this.liveId, this.limit = 20});

  @override
  List<Object?> get props => [liveId, limit];
}

/// Manual retry / pull-to-refresh.
class HourlyRankingRefreshRequested extends HourlyRankingEvent {
  const HourlyRankingRefreshRequested();
}

class HourlyRankingTabChanged extends HourlyRankingEvent {
  final HourlyRankingTab tab;

  const HourlyRankingTabChanged(this.tab);

  @override
  List<Object?> get props => [tab];
}

/// Socket `liveHourlyRankUpdated` arrived for the watched stream.
class HourlyRankingLiveRankUpdated extends HourlyRankingEvent {
  final LiveHourlyRank rank;

  const HourlyRankingLiveRankUpdated(this.rank);

  @override
  List<Object?> get props => [rank];
}

/// Reload the list without flipping the sheet back to its loading state.
class HourlyRankingSilentRefreshRequested extends HourlyRankingEvent {
  const HourlyRankingSilentRefreshRequested();
}
