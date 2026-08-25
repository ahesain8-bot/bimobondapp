import '../entities/fan_club.dart';
import '../repositories/fan_club_repository.dart';

/// Loads the member list of a creator's fan club.
class GetFanClubMembers {
  const GetFanClubMembers(this._repository);

  final FanClubRepository _repository;

  Future<List<FanClubMember>> call(String creatorId) {
    return _repository.members(creatorId);
  }
}
