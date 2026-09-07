import '../entities/fan_club.dart';
import '../repositories/fan_club_repository.dart';

/// Host action: enables / renames / prices the fan club.
class UpdateFanClub {
  const UpdateFanClub(this._repository);

  final FanClubRepository _repository;

  Future<FanClub> call(
    String creatorId, {
    bool? enabled,
    String? name,
    int? priceCoins,
  }) {
    return _repository.updateClub(
      creatorId,
      enabled: enabled,
      name: name,
      priceCoins: priceCoins,
    );
  }
}
