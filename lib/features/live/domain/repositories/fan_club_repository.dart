import '../entities/fan_club.dart';

/// Contract for Fan Club access (lives/mobile-api.md §20,
/// lives/live-p0-parity.md §4 for tiers, emotes and membership).
///
/// The presentation layer only knows this interface — the concrete
/// implementation lives in the data layer.
abstract interface class FanClubRepository {
  /// `GET /creators/:creatorId/fan-club` — club info, tiers, emotes,
  /// `membership` and `isMember`.
  Future<FanClub> getClub(String creatorId);

  /// `PATCH /creators/:creatorId/fan-club` — host enables / renames / prices.
  Future<FanClub> updateClub(
    String creatorId, {
    bool? enabled,
    String? name,
    int? priceCoins,
  });

  /// `POST /creators/:creatorId/fan-club/subscribe` `{ tierSlug }` — a coin
  /// purchase.
  ///
  /// [expectedPriceCoins] is the server-sent price the viewer was shown and
  /// agreed to; it is not sent to the server, it only proves the app is not
  /// charging for a tier whose price it never received.
  Future<FanClubSubscribeResult> subscribe(
    String creatorId, {
    required String tierSlug,
    required int expectedPriceCoins,
  });

  /// `DELETE /creators/:creatorId/fan-club/subscribe` — leave.
  Future<void> unsubscribe(String creatorId);

  /// `POST /creators/:creatorId/fan-club/emotes` — host adds an emote and the
  /// refreshed club is returned.
  Future<FanClub> addEmote(
    String creatorId, {
    required String code,
    required String imageUrl,
    String? minTier,
  });

  /// `GET /creators/:creatorId/fan-club/members` — member list.
  Future<List<FanClubMember>> members(String creatorId);

  /// `GET /users/me/fan-clubs` — clubs the caller joined.
  Future<List<FanClubSubscription>> myClubs();
}
