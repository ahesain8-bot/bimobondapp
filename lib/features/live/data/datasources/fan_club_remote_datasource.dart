import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';

/// HTTP access to the Fan Club endpoints (lives/mobile-api.md §20).
class FanClubRemoteDataSource {
  FanClubRemoteDataSource({LiveApiClient? apiClient})
    : _api = apiClient ?? LiveApiClient();

  final LiveApiClient _api;

  /// `GET /creators/:creatorId/fan-club` → `{ enabled, name, memberCount, isMember }`.
  Future<Map<String, dynamic>> getClub(String creatorId) {
    return _api.get(ApiEndpoints.creatorsFanClub(creatorId));
  }

  /// `PATCH /creators/:creatorId/fan-club`
  /// → `{ enabled, name, priceCoins }` (lives/live-p0-parity.md §4).
  Future<Map<String, dynamic>> updateClub(
    String creatorId, {
    bool? enabled,
    String? name,
    int? priceCoins,
  }) {
    if (priceCoins != null && priceCoins < 0) {
      throw ArgumentError.value(
        priceCoins,
        'priceCoins',
        'A membership price cannot be negative.',
      );
    }
    return _api.patch(
      ApiEndpoints.creatorsFanClub(creatorId),
      body: {
        if (enabled != null) 'enabled': enabled,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (priceCoins != null) 'priceCoins': priceCoins,
      },
    );
  }

  /// `POST /creators/:creatorId/fan-club/subscribe` `{ "tierSlug": "PLUS" }`.
  ///
  /// The tier is always the caller's explicit choice. The coin amount is the
  /// server's: the client never sends a price and never derives one.
  Future<Map<String, dynamic>> subscribe(
    String creatorId, {
    required String tierSlug,
  }) {
    final slug = tierSlug.trim().toUpperCase();
    if (slug.isEmpty) {
      throw ArgumentError.value(tierSlug, 'tierSlug', 'Choose a membership.');
    }
    return _api.post(
      ApiEndpoints.creatorsFanClubSubscribe(creatorId),
      body: {'tierSlug': slug},
    );
  }

  /// `POST /creators/:creatorId/fan-club/emotes` — host adds a club emote.
  Future<Map<String, dynamic>> addEmote(
    String creatorId, {
    required String code,
    required String imageUrl,
    String? minTier,
  }) {
    final trimmedCode = code.trim();
    final trimmedUrl = imageUrl.trim();
    if (trimmedCode.isEmpty || trimmedUrl.isEmpty) {
      throw ArgumentError('An emote needs a code and an image.');
    }
    return _api.post(
      ApiEndpoints.creatorsFanClubEmotes(creatorId),
      body: {
        'code': trimmedCode,
        'imageUrl': trimmedUrl,
        if (minTier != null && minTier.trim().isNotEmpty)
          'minTier': minTier.trim().toUpperCase(),
      },
    );
  }

  /// `DELETE /creators/:creatorId/fan-club/subscribe` — leave the club.
  Future<Map<String, dynamic>> unsubscribe(String creatorId) {
    return _api.delete(ApiEndpoints.creatorsFanClubSubscribe(creatorId));
  }

  /// `GET /creators/:creatorId/fan-club/members` → `{ data: Member[], meta }`.
  Future<Map<String, dynamic>> members(
    String creatorId, {
    int page = 1,
    int limit = 50,
  }) {
    return _api.get(
      ApiEndpoints.creatorsFanClubMembers(creatorId),
      query: {'page': '$page', 'limit': '$limit'},
    );
  }

  /// `GET /users/me/fan-clubs` → `{ data: Club[] }`.
  Future<Map<String, dynamic>> myClubs({int page = 1, int limit = 50}) {
    return _api.get(
      ApiEndpoints.usersMeFanClubs,
      query: {'page': '$page', 'limit': '$limit'},
    );
  }
}
