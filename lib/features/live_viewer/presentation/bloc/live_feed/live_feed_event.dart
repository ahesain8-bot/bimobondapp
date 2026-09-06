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
  final double? latitude, longitude;
  final bool audioOnly;

  const LiveFeedLoadRequested({
    this.category,
    this.refresh = false,
    this.followingOnly = false,
    this.latitude,
    this.longitude,
    this.audioOnly = false,
  });

  @override
  List<Object?> get props => [
    category,
    refresh,
    followingOnly,
    latitude,
    longitude,
    audioOnly,
  ];
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
