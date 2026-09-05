import 'package:equatable/equatable.dart';

abstract class LiveFeedEvent extends Equatable {
  const LiveFeedEvent();

  @override
  List<Object?> get props => const [];
}

class LiveFeedLoadRequested extends LiveFeedEvent {
  final String? category;
  final bool followingOnly;
  final bool refresh;

  const LiveFeedLoadRequested({
    this.category,
    this.followingOnly = false,
    this.refresh = false,
  });

  @override
  List<Object?> get props => [category, followingOnly, refresh];
}

class LiveFeedLoadMoreRequested extends LiveFeedEvent {
  final String? category;
  final bool? followingOnly;

  const LiveFeedLoadMoreRequested({this.category, this.followingOnly});

  @override
  List<Object?> get props => [category, followingOnly];
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
