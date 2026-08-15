import '../entities/fan_club.dart';
import '../repositories/fan_club_repository.dart';

/// Loads a creator's fan club info + membership state.
class GetFanClub {
  const GetFanClub(this._repository);

  final FanClubRepository _repository;

  Future<FanClub> call(String creatorId) {
    return _repository.getClub(creatorId);
  }
}
