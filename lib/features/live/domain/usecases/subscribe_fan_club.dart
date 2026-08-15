import '../repositories/fan_club_repository.dart';

/// Joins a creator's fan club (30-day subscription).
class SubscribeFanClub {
  const SubscribeFanClub(this._repository);

  final FanClubRepository _repository;

  Future<void> call(String creatorId) {
    return _repository.subscribe(creatorId);
  }
}
