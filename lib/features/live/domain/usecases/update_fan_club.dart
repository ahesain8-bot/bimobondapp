import '../entities/fan_club.dart';
import '../repositories/fan_club_repository.dart';

/// Host action: enables / renames the fan club.
class UpdateFanClub {
  const UpdateFanClub(this._repository);

  final FanClubRepository _repository;

  Future<FanClub> call(
    String creatorId, {
    bool? enabled,
    String? name,
  }) {
    return _repository.updateClub(
      creatorId,
      enabled: enabled,
      name: name,
    );
  }
}
