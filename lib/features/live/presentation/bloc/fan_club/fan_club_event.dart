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

/// Requests joining the club at [tierSlug] (`POST .../subscribe`).
///
/// The tier is always explicit: there is no default paid tier, because the app
/// must never charge for a membership the viewer did not pick and see priced.
class FanClubSubscribed extends FanClubEvent {
  const FanClubSubscribed(this.tierSlug);

  final String tierSlug;
}

/// Requests leaving the club (`DELETE .../subscribe`).
class FanClubUnsubscribed extends FanClubEvent {
  const FanClubUnsubscribed();
}

/// Requests the host to update the club name / enabled flag / BASIC price.
class FanClubUpdated extends FanClubEvent {
  const FanClubUpdated({this.name, this.enabled, this.priceCoins});

  final String? name;
  final bool? enabled;
  final int? priceCoins;
}

/// Host adds a club emote (`POST .../fan-club/emotes`).
class FanClubEmoteAdded extends FanClubEvent {
  const FanClubEmoteAdded({
    required this.code,
    required this.imageUrl,
    this.minTier,
  });

  final String code;
  final String imageUrl;
  final String? minTier;
}

/// Dismisses the current action message (snack bar).
class FanClubMessageShown extends FanClubEvent {
  const FanClubMessageShown();
}
