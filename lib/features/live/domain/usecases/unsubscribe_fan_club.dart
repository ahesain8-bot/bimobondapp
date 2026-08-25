import '../repositories/fan_club_repository.dart';

/// Leaves a creator's fan club.
class UnsubscribeFanClub {
  const UnsubscribeFanClub(this._repository);

  final FanClubRepository _repository;

  Future<void> call(String creatorId) {
    return _repository.unsubscribe(creatorId);
  }
}
