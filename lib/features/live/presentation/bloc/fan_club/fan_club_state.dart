import '../../../domain/entities/fan_club.dart';

/// States emitted by [FanClubBloc].
sealed class FanClubState {
  const FanClubState();
}

/// No data loaded yet.
class FanClubInitial extends FanClubState {
  const FanClubInitial();
}

/// Initial load in progress.
class FanClubLoading extends FanClubState {
  const FanClubLoading();
}

/// Data loaded and ready to render.
class FanClubReady extends FanClubState {
  const FanClubReady({
    required this.club,
    required this.members,
    required this.myClubs,
    this.creatorId,
    this.busy = false,
    this.message,
  });

  final FanClub club;
  final List<FanClubMember> members;
  final List<FanClubSubscription> myClubs;
  final String? creatorId;

  /// True while a subscribe/unsubscribe/update request is in flight.
  final bool busy;

  /// Short snack-bar message after an action.
  final String? message;

  FanClubReady copyWith({
    FanClub? club,
    List<FanClubMember>? members,
    List<FanClubSubscription>? myClubs,
    String? creatorId,
    bool? busy,
    String? message,
    bool clearMessage = false,
  }) {
    return FanClubReady(
      club: club ?? this.club,
      members: members ?? this.members,
      myClubs: myClubs ?? this.myClubs,
      creatorId: creatorId ?? this.creatorId,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// Initial load failed.
class FanClubFailure extends FanClubState {
  const FanClubFailure({required this.message});

  final String message;
}
