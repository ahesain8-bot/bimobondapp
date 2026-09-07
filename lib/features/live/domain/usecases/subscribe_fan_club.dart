import '../entities/fan_club.dart';
import '../repositories/fan_club_repository.dart';

/// Joins a creator's fan club at a chosen tier (30-day subscription, paid in
/// coins — lives/live-p0-parity.md §4).
///
/// The use case refuses the purchase unless the tier the viewer picked carries
/// a price that came from the server, and unless that price is still the one
/// the viewer was shown. It never derives a price from another tier.
class SubscribeFanClub {
  const SubscribeFanClub(this._repository);

  final FanClubRepository _repository;

  Future<FanClubSubscribeResult> call(
    String creatorId, {
    required FanClub club,
    required String tierSlug,
  }) {
    final tier = club.tierBySlug(tierSlug);
    if (tier == null || !tier.isPurchasable) {
      throw FanClubPriceUnverified(tierSlug);
    }
    return _repository.subscribe(
      creatorId,
      tierSlug: tier.slug,
      expectedPriceCoins: tier.priceCoins!,
    );
  }
}
