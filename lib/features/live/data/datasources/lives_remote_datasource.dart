import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';

/// HTTP access to `/lives` and `/gifts` endpoints documented in mobile-api.md.
class LivesRemoteDataSource {
  LivesRemoteDataSource({LiveApiClient? apiClient})
      : _api = apiClient ?? LiveApiClient();

  final LiveApiClient _api;

  /// `POST /lives` with `startNow: true` → `{ live, token, url, role }`.
  Future<Map<String, dynamic>> createAndStart({
    required String title,
    String? coverUrl,
    String? categoryId,
  }) {
    return _api.post(
      ApiEndpoints.lives,
      body: {
        'title': title,
        'startNow': true,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
  }

  Future<Map<String, dynamic>> end(String liveId) {
    return _api.post(ApiEndpoints.liveEnd(liveId));
  }

  /// `POST /lives/:id/start` → `{ live, token, url, role: "host" }`.
  Future<Map<String, dynamic>> start(String liveId) {
    return _api.post(ApiEndpoints.liveStart(liveId));
  }

  /// `POST /lives/:id/join` → `{ live, token, url, role, guest }`.
  Future<Map<String, dynamic>> join(String liveId) {
    return _api.post(ApiEndpoints.liveJoin(liveId));
  }

  /// `POST /lives/:id/leave` → `{ success, viewers }`.
  Future<Map<String, dynamic>> leave(String liveId) {
    return _api.post(ApiEndpoints.liveLeave(liveId));
  }

  /// `GET /lives/feed` → `{ data, meta }`.
  Future<Map<String, dynamic>> feed({
    int page = 1,
    int limit = 20,
    String? categoryId,
    bool followingOnly = false,
  }) {
    return _api.get(
      ApiEndpoints.livesFeed,
      auth: true,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (categoryId != null) 'categoryId': categoryId,
        'followingOnly': '$followingOnly',
      },
    );
  }

  Future<Map<String, dynamic>> getById(String liveId) {
    return _api.get(ApiEndpoints.liveById(liveId));
  }

  /// `GET /lives/mine` → `{ data, meta }` (all statuses for the caller).
  Future<Map<String, dynamic>> mine({
    int page = 1,
    int limit = 20,
  }) {
    return _api.get(
      ApiEndpoints.livesMine,
      query: {
        'page': '$page',
        'limit': '$limit',
      },
    );
  }

  Future<Map<String, dynamic>> updateLive(
    String liveId, {
    String? title,
    String? coverUrl,
  }) {
    return _api.patch(
      ApiEndpoints.liveById(liveId),
      body: {
        if (title != null) 'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
      },
    );
  }

  Future<Map<String, dynamic>> like(String liveId) {
    return _api.post(ApiEndpoints.liveLike(liveId));
  }

  Future<Map<String, dynamic>> sendComment({
    required String liveId,
    required String content,
  }) {
    return _api.post(
      ApiEndpoints.liveComments(liveId),
      body: {'content': content},
    );
  }

  Future<Map<String, dynamic>> listComments({
    required String liveId,
    int page = 1,
    int limit = 50,
  }) {
    return _api.get(
      ApiEndpoints.liveComments(liveId),
      query: {
        'page': '$page',
        'limit': '$limit',
      },
    );
  }

  Future<Map<String, dynamic>> deleteComment({
    required String liveId,
    required String commentId,
  }) {
    return _api.delete(ApiEndpoints.liveCommentById(liveId, commentId));
  }

  Future<Map<String, dynamic>> pinComment({
    required String liveId,
    required String commentId,
  }) {
    return _api.post(ApiEndpoints.liveCommentPin(liveId, commentId));
  }

  Future<Map<String, dynamic>> unpinComment({
    required String liveId,
    required String commentId,
  }) {
    return _api.post(ApiEndpoints.liveCommentUnpin(liveId, commentId));
  }

  Future<Map<String, dynamic>> muteViewerChat({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _api.post(
      ApiEndpoints.liveViewerMuteChat(liveId, userId),
      body: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<Map<String, dynamic>> unmuteViewerChat({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveViewerUnmuteChat(liveId, userId));
  }

  Future<Map<String, dynamic>> banViewer({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _api.post(
      ApiEndpoints.liveViewerBan(liveId, userId),
      body: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<Map<String, dynamic>> unbanViewer({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveViewerUnban(liveId, userId));
  }

  Future<Map<String, dynamic>> gallery(String liveId) {
    return _api.get(ApiEndpoints.liveGallery(liveId));
  }

  Future<Map<String, dynamic>> pinAuction({
    required String liveId,
    required String auctionId,
    required bool pinned,
  }) {
    return _api.patch(
      ApiEndpoints.liveAuctionPin(liveId, auctionId),
      body: {'pinned': pinned},
    );
  }

  Future<Map<String, dynamic>> reorderAuctions({
    required String liveId,
    required List<String> auctionIds,
  }) {
    return _api.patch(
      ApiEndpoints.liveAuctionsReorder(liveId),
      body: {'auctionIds': auctionIds},
    );
  }

  Future<Map<String, dynamic>> guests(String liveId) {
    return _api.get(ApiEndpoints.liveGuests(liveId));
  }

  Future<Map<String, dynamic>> inviteGuest({
    required String liveId,
    required String userId,
    String role = 'GUEST',
  }) {
    return _api.post(
      ApiEndpoints.liveGuestInvite(liveId),
      body: {
        'userId': userId,
        'role': role,
      },
    );
  }

  Future<Map<String, dynamic>> acceptGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestAccept(liveId, userId));
  }

  Future<Map<String, dynamic>> rejectGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestReject(liveId, userId));
  }

  Future<Map<String, dynamic>> kickGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestKick(liveId, userId));
  }

  Future<Map<String, dynamic>> muteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestMute(liveId, userId));
  }

  Future<Map<String, dynamic>> unmuteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestUnmute(liveId, userId));
  }

  Future<Map<String, dynamic>> guestCameraOff({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestCameraOff(liveId, userId));
  }

  Future<Map<String, dynamic>> guestCameraOn({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestCameraOn(liveId, userId));
  }

  Future<Map<String, dynamic>> promoteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestPromote(liveId, userId));
  }

  Future<Map<String, dynamic>> demoteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestDemote(liveId, userId));
  }

  Future<Map<String, dynamic>> hourlyLeaderboard(String liveId) {
    return _api.get(ApiEndpoints.liveHourlyLeaderboard(liveId));
  }

  Future<Map<String, dynamic>> globalHourlyLeaderboard({int limit = 20}) {
    return _api.get(
      ApiEndpoints.livesHourlyLeaderboard,
      query: {'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> giftersLeaderboard(
    String liveId, {
    String window = 'hour',
  }) {
    return _api.get(
      ApiEndpoints.liveGiftersLeaderboard(liveId),
      query: {'window': window},
    );
  }

  Future<Map<String, dynamic>> updateSettings(
    String liveId, {
    bool? guestsEnabled,
    String? guestRequestMode,
    int? maxGuests,
    String? layout,
    bool? allowGuestCamera,
    bool? moderatorsCanManageGuests,
  }) {
    return _api.patch(
      ApiEndpoints.liveSettings(liveId),
      body: {
        if (guestsEnabled != null) 'guestsEnabled': guestsEnabled,
        if (guestRequestMode != null) 'guestRequestMode': guestRequestMode,
        if (maxGuests != null) 'maxGuests': maxGuests,
        if (layout != null) 'layout': layout,
        if (allowGuestCamera != null) 'allowGuestCamera': allowGuestCamera,
        if (moderatorsCanManageGuests != null)
          'moderatorsCanManageGuests': moderatorsCanManageGuests,
      },
    );
  }
}
