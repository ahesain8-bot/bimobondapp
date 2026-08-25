/// Events handled by [FanClubBloc].
sealed class FanClubEvent {
  const FanClubEvent();
}

/// Requests loading the club, members and my-clubs in one shot.
class FanClubLoaded extends FanClubEvent {
  const FanClubLoaded({this.creatorId});

  /// Optional creator id; when omitted the bloc resolves the signed-in user.
  final String? creatorId;
}

/// Requests joining the club (`POST .../subscribe`).
class FanClubSubscribed extends FanClubEvent {
  const FanClubSubscribed();
}

/// Requests leaving the club (`DELETE .../subscribe`).
class FanClubUnsubscribed extends FanClubEvent {
  const FanClubUnsubscribed();
}

/// Requests the host to update the club name / enabled flag.
class FanClubUpdated extends FanClubEvent {
  const FanClubUpdated({this.name, this.enabled});

  final String? name;
  final bool? enabled;
}

/// Dismisses the current action message (snack bar).
class FanClubMessageShown extends FanClubEvent {
  const FanClubMessageShown();
}
