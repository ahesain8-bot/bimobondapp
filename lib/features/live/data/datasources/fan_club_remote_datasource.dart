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

  /// `PATCH /creators/:creatorId/fan-club` → `{ enabled, name }`.
  Future<Map<String, dynamic>> updateClub(
    String creatorId, {
    bool? enabled,
    String? name,
  }) {
    return _api.patch(
      ApiEndpoints.creatorsFanClub(creatorId),
      body: {
        if (enabled != null) 'enabled': enabled,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );
  }

  /// `POST /creators/:creatorId/fan-club/subscribe` — join the club.
  Future<Map<String, dynamic>> subscribe(String creatorId) {
    // Send an empty JSON body `{}` — the server rejects requests that carry
    // `Content-Type: application/json` with no body (400).
    return _api.post(
      ApiEndpoints.creatorsFanClubSubscribe(creatorId),
      body: <String, dynamic>{},
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
