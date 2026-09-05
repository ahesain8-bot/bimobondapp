import 'package:equatable/equatable.dart';

abstract class LiveFeedEvent extends Equatable {
  const LiveFeedEvent();

  @override
  List<Object?> get props => const [];
}

class LiveFeedLoadRequested extends LiveFeedEvent {
  final String? category;
  final bool refresh;
  final bool followingOnly;

  const LiveFeedLoadRequested({
    this.category,
    this.refresh = false,
    this.followingOnly = false,
  });

  @override
  List<Object?> get props => [category, refresh, followingOnly];
}

class LiveFeedLoadMoreRequested extends LiveFeedEvent {
  final String? category;

  const LiveFeedLoadMoreRequested({this.category});

  @override
  List<Object?> get props => [category];
}

class LiveFeedRefreshRequested extends LiveFeedEvent {
  const LiveFeedRefreshRequested();
}

class LiveFeedSilentRefreshRequested extends LiveFeedEvent {
  const LiveFeedSilentRefreshRequested();
}

class LiveFeedLiveRemoved extends LiveFeedEvent {
  final String liveId;

  const LiveFeedLiveRemoved(this.liveId);

  @override
  List<Object?> get props => [liveId];
}
