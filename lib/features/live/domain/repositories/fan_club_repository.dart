import '../entities/fan_club.dart';

/// Contract for Fan Club access (lives/mobile-api.md §20).
///
/// The presentation layer only knows this interface — the concrete
/// implementation lives in the data layer.
abstract interface class FanClubRepository {
  /// `GET /creators/:creatorId/fan-club` — club info + `isMember`.
  Future<FanClub> getClub(String creatorId);

  /// `PATCH /creators/:creatorId/fan-club` — host enables / renames.
  Future<FanClub> updateClub(
    String creatorId, {
    bool? enabled,
    String? name,
  });

  /// `POST /creators/:creatorId/fan-club/subscribe` — join (30-day).
  Future<void> subscribe(String creatorId);

  /// `DELETE /creators/:creatorId/fan-club/subscribe` — leave.
  Future<void> unsubscribe(String creatorId);

  /// `GET /creators/:creatorId/fan-club/members` — member list.
  Future<List<FanClubMember>> members(String creatorId);

  /// `GET /users/me/fan-clubs` — clubs the caller joined.
  Future<List<FanClubSubscription>> myClubs();
}
