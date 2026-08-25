import '../entities/fan_club.dart';
import '../repositories/fan_club_repository.dart';

/// Loads the fan clubs the signed-in user has joined.
class GetMyFanClubs {
  const GetMyFanClubs(this._repository);

  final FanClubRepository _repository;

  Future<List<FanClubSubscription>> call() {
    return _repository.myClubs();
  }
}
