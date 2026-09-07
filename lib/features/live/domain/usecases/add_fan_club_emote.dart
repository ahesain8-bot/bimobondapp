import '../entities/fan_club.dart';
import '../repositories/fan_club_repository.dart';

/// Host action: adds a club emote and returns the refreshed club
/// (`POST /creators/:id/fan-club/emotes`).
class AddFanClubEmote {
  const AddFanClubEmote(this._repository);

  final FanClubRepository _repository;

  Future<FanClub> call(
    String creatorId, {
    required String code,
    required String imageUrl,
    String? minTier,
  }) {
    return _repository.addEmote(
      creatorId,
      code: code,
      imageUrl: imageUrl,
      minTier: minTier,
    );
  }
}
